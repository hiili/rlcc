classdef AgentLSPI < Agent
  %AGENTLSPI Least-squares policy iteration (on-policy).
  %
  %   Least-squares policy iteration, as in (Lagoudakis & Parr, 2003)
  %   except that evaluation is performed in an on-policy manner and
  %   eligibility traces are supported. The returned action is an index to
  %   a row in the 'actions' matrix.
  %
  %   References
  %     Lagoudakis & Parr (2003). Least-squares policy iteration.
  
  % NOTE: Vectors are column vectors by default.
  %
  % TODO: try an off-policy version (should be fast even in Matlab). We
  % have enough information in the Tetris case if we store also the
  % saFeatures for each step (they give the state featurization of the next
  % state after any action, as long as the bias term is not replaced by the
  % immediate reward).
  
  properties (Access=protected)
    
    % state and state-action dimensions, critic dimensions.
    sDim, saDim, criticDim;
    
    % whether to estimate an advantage function or just a plain action
    % value function. type: logical
    useAdvantages;
    
    
    % the critic
    critic;
    
    % initial parameters, or [] to use zero values
    w0;
    
    
    % exploration temperature (Boltzmann exploration)
    epsilon;
    
    % The policy parameters. type: column double array, length: saDim
    w;
    
    
    % The previous and current state features (s0, s1)
    prevsFeatures, sFeatures;
    
    % The previous and current action features (sa0, sa1)
    prevsaFeatures, saFeatures;
    
    % The previous and current action probabilities
    prevActionProbabilities, actionProbabilities;
    
    % The previous and current actions (a0, a1)
    prevAction, action;
    
    % The previous reward (r)
    prevReward;
    
  end
  
  
  methods
    
    function this = AgentLSPI( critic, varargin )
      
      this.critic = critic;
      
      args = inputParser;
      args.addParamValue( 'use_advantages', true, @islogical );
      args.addParamValue( 'epsilon', 1e-3, @isnumeric );
      args.addParamValue( 'w0', [], @isnumeric );
      args.parse( varargin{:} );
      
      this.useAdvantages = args.Results.use_advantages;
      this.epsilon = args.Results.epsilon;
      this.w0 = args.Results.w0(:);   % enforce into a column array
      
    end
    
    % Requires special environment property fields (environment.props) at
    % the moment:
    %   stateActionDim
    %
    % only continuous state-action features allowed (not checked!).
    % oaRanges is not supported.
    function this = init( this, varargin )
      this = init@Agent( this, varargin{:} );
      
      assert( this.props.actionDim == 1 && this.props.actionTypes == 'd' && this.props.actionRanges(1,1) == 1 && ...
              isempty(this.props.oaRanges) );
      
      % compute state and state-action dimensionality
      this.sDim = this.props.stateDim;
      this.saDim = this.props.stateActionDim;
      
      % compute critic dimensionality
      if this.useAdvantages
        this.criticDim = this.sDim + this.saDim;
      else
        this.criticDim = this.saDim;
      end
      
      % check w0
      if isempty(this.w0); this.w0 = zeros( this.saDim, 1 ); end
      
      % init params and critic for the first time
      this = reset( this );
      
    end
    
    function this = reset( this )
      this = reset@Agent( this );
      
      % reset the policy
      this.w = this.w0;
      
      % reset the critic
      this.critic = reset( this.critic, this.criticDim );
      
    end
    
    function this = newEpisode( this )
      this = newEpisode@Agent( this );
      
      this.prevsFeatures = []; this.prevsaFeatures = [];
      this.prevActionProbabilities = []; this.prevAction = []; this.prevReward =[];
      this.sFeatures = []; this.saFeatures = []; this.actionProbabilities = []; this.action = [];
      
    end
    
    % Step the agent to the next time intant.
    %
    %   (double) reward
    %     The immediate reward that followed the previous state-action
    %   sFeatures
    %     The current state feature activations. type: column double array
    %   saFeatures
    %     The current state-action feature activations. type: double matrix
    %   (int) action
    %     Index of the selected action: this is a row index into the
    %     saFeatures matrix.
    %
    %   Input features
    %
    %   The state feature vector defines the feature activations for the
    %   current state. The state-action feature matrix defines the feature
    %   activations for the currently available state-actions. This will be
    %   used in estimation of the action value function Q. There will be
    %   critic parameters for each column of the saFeatures matrix, which
    %   will encode the action values.
    %
    %   Each row of the saFeatures matrix represents an available action:
    %   row i contains the feature activations for action i. See
    %   Environment.getAvailableActions().
    function [this, action] = step( this, reward, sFeatures, saFeatures )
      this = step@Agent( this, reward, sFeatures, saFeatures );
      
      % we require an explicit action list here (check for terminal state)
      if ~isempty(sFeatures); assert( ~isempty(saFeatures) ); end
      
      % keep previous state, state-actions and reward for learning
      this.prevsFeatures = this.sFeatures;
      this.prevsaFeatures = this.saFeatures;
      this.prevActionProbabilities = this.actionProbabilities;
      this.prevAction = this.action;
      this.prevReward = reward;
      
      % step: update the current state and action
      if ~isempty(sFeatures)
        this.sFeatures = sFeatures;
        this.saFeatures = saFeatures;
        this.action = decideAction( this, this.saFeatures );
      else
        % terminal state
        this.sFeatures = []; this.saFeatures = []; this.action = [];
      end
      
      % learn if learning is enabled and not the first step
      if this.learning && ~isempty( this.prevsFeatures )
        this = learn( this, this.prevsFeatures, this.prevsaFeatures, this.prevActionProbabilities, ...
                      this.prevAction, this.prevReward, ...
                      this.sFeatures, this.saFeatures, this.action );
      end
      
      % set the return value
      action = this.action;
      
    end
    
    % Update the actor based on the critic, then reset the critic
    function this = improve( this )
      
      % update the critic
      this.critic = computeV( this.critic );
      
      % update the actor
      this.w = getQ(this)';
      
      % reset the critic
      this.critic = reset( this.critic, this.criticDim );
      
      this = improve@Agent( this );
    end
    
    
    % return the state value function as a row vector, or [] if not using
    % advantages (in which case V is not estimated)
    function V = getV( this )
      
      if ~this.useAdvantages; V = []; return; end
      
      % update the critic
      this.critic = computeV( this.critic );
      
      % get V and A, return V
      V = this.critic.V(1:this.sDim)';
      
    end
    
    % return the action value or advantage function as a row vector
    function Q = getQ( this )
      
      % get the critic solution
      this.critic = computeV( this.critic );
      Q = this.critic.V';
      
      % drop V part if using advantages
      if this.useAdvantages; Q(1:this.sDim) = []; end
      
    end
    
    % not supported
    function Pi = getPi( this ); Pi = []; end
    
    % Return the parameter vector as a row vector.
    function theta = getTheta( this )
      theta = this.w';
    end
    
    function [this, data] = mexFork( this, useMex )
      [this, data] = mexFork@Agent( this, useMex );
      
      if useMex
        data.w = this.w;
        data.gamma = this.critic.gamma;
        data.lambda = this.critic.lambda;
      end
      
    end
    
    function this = mexJoin( this, data )
      this = mexJoin@Agent( this, data );
      
      if ~isempty(data)
        % returning from a mex call
        this.critic = this.critic.addData( data.critic );
      end
      
    end
    
  end
  
  
  % private methods begin
  
  
  methods (Access=protected)
    
    % Decide on an action based on this.w and the features of available
    % actions that are along the rows of 'saFeatures'.
    function a = decideAction( this, saFeatures )
      
      % compute value estimates for each action (rows in saFeatures)
      Q = saFeatures * this.w; Q = Q - max(Q);   % avoid overflow
      
      % set temperature and exponentiate
      Q = exp(Q / this.epsilon);
      
      % normalize and store
      this.actionProbabilities = Q / sum(Q);

      % sample the action
      a = randDiscretePdf( this, this.actionProbabilities );
      
    end
    
    % On-policy learning. See (Peters, 2007, Table 4.5). Critic is updated
    % on each call. The actor updating is considered only during episode
    % changes, ie, when phi_s1, phi_sa1, and a1 are [] (which means that
    % the current state is a terminal state).
    %
    %   (column double vector) phi_s0
    %     state feature activations for previous state
    %   (column double vector) phi_sa0
    %     state-action feature activations for previous state-actions
    %   (column double vector) pi0
    %     action probabilities for previous state
    %   (int) a0
    %     action index for previous state
    %   (double) r0
    %     reward for previous state-action
    %   (column double vector) phi_s1
    %     state feature activations for current state
    %   (column double vector) phi_sa1
    %     state-action feature activations for current state-actions
    %   (int) a1
    %     action index for current state
    function this = learn( this, phi_s0, phi_sa0, pi0, a0, r0, phi_s1, phi_sa1, a1 )
      
      % a1 and phi_sa1 might be [] if in terminal state, in which case form
      % a zero vector and set the action to it (value of a terminal state
      % is 0)
      if isempty(a1)
        a1 = 1;
        phi_s1 = zeros(1, this.sDim);
        phi_sa1 = zeros(1, this.saDim);
      end
      
      % update critic
      if this.useAdvantages
        
        switch 2
          case 1
            this.critic = step( this.critic, [ phi_s0' ; phi_sa0(a0,:)' ], ...
                                             [ phi_s1' ; zeros(this.saDim, 1) ], ...
                                r0 );
          case 2
            grad_log_pi0_a0 = phi_sa0(a0,:)' - phi_sa0' * pi0;
            %grad_log_pi0_a0 = pi0(a0) * grad_log_pi0_a0;   % try normalizing. justification?
            this.critic = step( this.critic, [ phi_s0' ; grad_log_pi0_a0(:) ], ...
                                             [ phi_s1' ; zeros(this.saDim, 1) ], ...
                                r0 );
        end
        
      else
        this.critic = step( this.critic, phi_s0', phi_s1', r0 );
      end
      
    end
    
    
    % Select a random element from the row or column vector v with p(I=i|v)
    % = v(i). The index of the element is returned. The probability vector
    % v does not need to be normalized.
    function i = randDiscretePdf( this, v )
      
      % (re)normalizing here protects against rounding error problems
      cs = cumsum(v); cs = cs ./ cs(end);
      i = find( rand(this.rstream) < cs, 1 );
      
    end
    
  end
  
end
