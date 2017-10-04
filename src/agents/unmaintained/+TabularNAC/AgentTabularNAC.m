classdef AgentTabularNAC < Agent
  %AGENTTABULARNAC Tabular natural actor-critic with linear superposition
  %states.
  %
  %   Natural actor-critic with tabular representation, except that linear
  %   state-action superpositions are supported. This provides
  %   compatibility with wrappers (featurizers) that are intended for
  %   implementing linear in parameters function approximation. This has
  %   the following concrete meanings:
  %       1) The current state input is a (sparse) column vector of
  %       non-negative activation weights over the discrete state space
  %       that sum up to one. The current state is interpreted to be the
  %       linear superposition of all states weighted by the state input
  %       vector. Alternatively a single state index can be provided, in
  %       which case the current state is interpreted to be exactly that
  %       state. [TODO: how about an _arbitrary_ state vector?]
  %       2) The returned action is an index indicating the selected
  %       discrete action (no support for approximations in the action
  %       space)
  %   Thus, the representational structure of the state-space distribution
  %   function is fully defined within the featurizer class and the
  %   representational structure of the action-space distribution function
  %   is fully defined within the agent class. (see comments in wiki, and
  %   below, on reasons for not encapsulating also the action distribution
  %   function into the featurizer)
  %
  %   References
  %     Peters (2007). Machine learning of motor skills for robotics.
  
  % NOTE: Actions are along the first dimension and states along the second
  % in matrices, which currently differs from the Q-learning and SARSA
  % agent!
  %
  % NOTE: Vectors are column vectors by default.
  %
  % TODO: Move trashed comments into wiki.
  %
  % TRASH: 2) The action output is a (sparse) vector of probabilities
  %   over the discrete action space. The featurizer performs the sampling
  %   of the actual action from this probability distribution. The final
  %   action decision is communicated back via the learn() call.
  % RATIONALE: the featurizer would need to compute either
  %       1) pi = prod( a .^ phi_a ) / z, or
  %       2) pi = exp( a' phi_a ) / z,
  %   where a contains _unnormalized_ probabilities and z is used for
  %   normalization. In both cases the featurizer would be somewhat
  %   dependent on the policy representation that the actor uses, and thus
  %   the whole point of trying to separate these is lost.
  
  % TODO: Refactor common code out from AgentTabularNAC and
  % AgentOnlineGreedyTD. (there is a lot!)
  %
  % TODO: line search or some basic stepsize schedule
  %
  % TODO: terminology: no 'observations', but states and then maybe later
  % use state and talk about augmentation
  
  properties (Access=private)
    
    % state, action and state-dependent action counts (observations are
    % used as states) (saCounts is a column vector with length == sCount).
    sCount, aCount, saCounts;
    
    % Critic dimensionality.
    criticK;
    
    
    % The actor parameter matrix. theta(a,s) is the parameter for action a
    % in state s. Elements outside the saCounts ranges (theta(a,s) for all
    % a > saCounts(s)) are -realmax.
    theta;
    
    
    % the critic
    critic;
    
    % stepsize
    stepsize;
    
    
    % The previous and current state estimates (s0, s1)
    prevState, state;
    
    % The previous and current actions (a0, a1)
    prevAction, action;
    
    % The previous reward (r)
    prevReward;
    
  end
  
  
  methods
    
    function this = AgentTabularNAC( critic, varargin )
      
      this.critic = critic;
      
      args = inputParser;
      args.addParamValue( 'stepsize', 1, @(x) (isnumeric(x) && isscalar(x)) );
      args.parse( varargin{:} );
      
      this.stepsize = args.Results.stepsize;
      
    end
    
    function this = init( this, varargin )
      this = init@Agent( this, varargin{:} );
      
      % only discrete variables allowed. only one state and one action
      % variable allowed.
      assert( this.props.observationDim == 1 && this.props.actionDim == 1 && ...
              this.props.observationTypes == 'd' && this.props.actionTypes == 'd' && ...
              this.props.observationRanges(1,1) == 1 && this.props.actionRanges(1,1) == 1 );
      
      % compute state, action and observation-dependent action
      % dimensionality (use observations as states)
      this.sCount = this.props.observationRanges(1,2);
      this.aCount = this.props.actionRanges(1,2);
      this.saCounts = this.props.oaRanges';
      if isempty(this.saCounts)
        this.saCounts = repmat( this.aCount, this.sCount, 1 );
      end
      
      % compute critic dimensionality
      this.criticK = this.sCount + this.aCount * this.sCount;
      
      % init params and critic for the first time
      this = reset( this );
      
    end
    
    function this = reset( this )
      this = reset@Agent( this );
      
      % reset theta: -realmax for disabled actions and 0 for the rest
      this.theta = -ones( this.aCount, this.sCount ) * realmax;
      for s=1:this.sCount
        this.theta(1:this.saCounts(s),s) = eps * zeros( this.saCounts(s), 1 ); % TODO: why 'eps*'?
      end
      
      % reset the critic
      this.critic = reset( this.critic, this.criticK );
      
    end
    
    function this = newEpisode( this )
      this = newEpisode@Agent( this );
      
      this.prevState = []; this.prevAction = []; this.prevReward =[];
      this.state = []; this.action = [];
      
    end
    
    function [this, action] = step( this, reward, observation, actions )
      this = step@Agent( this, reward, observation, actions );
      
      % explicit action lists are not supported
      assert( isempty(actions) );
      
      % is observation an index? convert to weight vector (no harm would be
      % done even if sCount == 1)
      if this.sCount > 1 && isscalar( observation )
        ind = observation;
        observation = zeros(this.sCount, 1); observation(ind) = 1;
      end
      
      % keep previous state estimate, action and reward for learning
      this.prevState = this.state;
      this.prevAction = this.action;
      this.prevReward = reward;
      
      % step: update the current state estimate and action
      if ~isempty(observation)
        this.state = observation;   % use directly as states
        this.action = decideAction( this, this.state );
      else
        % terminal state
        this.state = []; this.action = [];
      end
      
      % learn if learning is enabled and not the first step
      if this.learning && ~isempty( this.prevState )
        this = learn( this, this.prevState, this.prevAction, this.prevReward, this.state, this.action );
      end
      
      % set the return value
      action = this.action;
      
    end
    
    % Update the actor based on the critic, then reset the critic
    function this = improve( this )
      
      % update the critic
      this.critic = computeV( this.critic );
      
      % get the V and A estimates (state values and action advantages),
      % select A and reshape into a gradient matrix
      grad_theta = reshape( this.critic.V(this.sCount+1:end), this.aCount, this.sCount );
      
      % update the actor
      this.theta = this.theta + this.stepsize * grad_theta;
      
      % reset the critic
      this.critic = reset( this.critic, this.criticK );
      
      this = improve@Agent( this );
    end
    
    
    % Return the state value function as a row vector.
    function V = getV( this )
      
      % get the V and A estimates (state values and action advantages) and
      % select state values
      V = full(this.critic.V(1:this.sCount)');
      
    end
    
    % Return the advantage function as a row vector.
    function Q = getQ( this )
      
      % get the V and A estimates (state values and action advantages) and
      % select action advantages
      Q = full(this.critic.V(this.sCount+1:end)');
      
      % shuffle actions to be dominant
      Q = reshape( Q, this.aCount, this.sCount )'; Q = Q(:)';
      
    end
    
    % Return the policy (action probabilities) as a row vector. Pi is
    % flattened from Pi(S,A), where Pi(S=s,A=a) is the probability of
    % action a in feature state s (the state in which feature s is the only
    % active feature). (assume unit action basis)
    function Pi = getPi( this )
      
      x = this.theta - max(this.theta(:));   % avoid overflow
      Pi = exp(x) ./ repmat( sum(exp(x)), this.aCount, 1 );
      
      % shuffle actions to be dominant, then flatten
      Pi = Pi'; Pi = Pi(:)';
      
    end
    
    % Return the parameter matrix as a row vector. (dimensions switched)
    function theta = getTheta( this )
      
      theta = this.theta'; theta = theta(:)';
      theta(theta==-realmax) = nan;
      
    end
    
  end
  
  
  % private methods begin
  
  
  methods (Access=private)
    
    function a = decideAction( this, s )
      
      % compute unnormalized probabilities and sample the action (discrete
      % actions)
      x = this.theta * s; x = x - max(x);   % avoid overflow
      a = randDiscretePdf( this, exp(x) );
      
    end
    
    % On-policy learning. See (Peters, 2007, Table 4.5). Critic is updated
    % on each call. The actor updating is considered only during episode
    % changes, ie, when phi_s1 and a1 are [] (which means that the current
    % state is a terminal state).
    %
    %   (column double vector) phi_s0
    %     state feature activations for previous state
    %   (int) a0
    %     action index for previous state
    %   (double) r0
    %     reward for previous state-action
    %   (column double vector) phi_s1
    %     state feature activations for current state
    %   (int) a1
    %     action index for current state
    function this = learn( this, phi_s0, a0, r0, phi_s1, a1 )
      
      % phi_s1 might be [] if in terminal state, in which case form a zero
      % vector (value of a terminal state is 0)
      if isempty(phi_s1); phi_s1 = zeros(this.sCount, 1); end
      
      % convert action indices into column action vectors (a1 might be [],
      % which is ok)
      phi_a0 = zeros(this.aCount, 1); phi_a0(a0) = 1;
      phi_a1 = zeros(this.aCount, 1); phi_a1(a1) = 1;
      
      % feature activation matrix for previous state-action
      phi_s0a0 = phi_a0 * phi_s0';
      
      
      % normalized action probabilities for previous state (column vector
      % over actions) (assume unit action basis). all actions which are
      % disabled in _any_ state with non-zero weight become considered
      % disabled.
      x = this.theta * phi_s0; x = x - max(x);   % avoid overflow
      pi_s0 = exp(x); pi_s0 = (pi_s0 / sum(pi_s0));
      
      % gradient matrix of the logarithm of the probability of action a0 in
      % state phi_s0 (assume unit action basis)
      grad_log_pi_a0 = phi_s0a0 - pi_s0 * phi_s0';
      
      
      % previous state in critic's basis. phi_hat in (Peters, 2007)
      critic_sa0 = [ phi_s0 ; grad_log_pi_a0(:) ];
      
      % current state in critic's basis. phi_tilde in (Peters, 2007)
      critic_sa1 = [ phi_s1 ; zeros(this.aCount*this.sCount, 1) ];
      
      
      % update critic
      this.critic = step( this.critic, sparse(critic_sa0), sparse(critic_sa1), r0 );
      
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
