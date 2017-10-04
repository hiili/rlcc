classdef AgentNaturalActorCritic < Agent
  %AGENTNATURALACTORCRITIC Generic Gibbs policy agent.
  %
  %   Generic agent using the Gibbs policy. The class is mainly geared to
  %   implement the natural actor-critic algorithm, although it can be
  %   configured to implement also several greedy algorithms.
  %
  %   This agent works only with environments that use action lists (see
  %   Environment). The returned action is an index to a row in the actions
  %   matrix.
  %
  %   References
  %     Peters (2007). Machine learning of motor skills for robotics.
  
  % NOTE: Vectors are column vectors by default.
  %
  % BUG: The Matlab implementation (vs. mex) is not well tested in its
  % current state. There are issues, see Agent.m and Critic.m.
  %
  % BUG (on-line mode): theta might have been changed between deciding a0 and learning!
  %    
  % TODO: Rename to ActorGibbs or something, or refactor the Gibbs policy
  % and advantage function basis stuff out to a separate class and rename
  % to Actor or something. The point being that this class can already
  % implement several greedy methods and is not NAC-specific anymore in any
  % sense.
  %
  % TODO: Make protected fields public, remove setTheta0.
  
  properties (Access=protected)
    
    % state and state-action dimensions
    sDim, aDim;
    
    
    % stepsize
    stepsize;
    
    % initial parameters, or [] to use zero values
    theta0;
    
    % theta constraint
    thetaC;
    
    % policy forgetting factor
    beta;
    
    % policy temperature
    tau;
    
    % Interpretation of Q. Either 'gradient' or 'target'.
    QInterpretation;
    
    
    % the critic
    critic;
    
    % The actor parameter column vector. type: column double array, length: aDim
    theta;
    
    
    % Current and previous state. Fields:
    %   .sFeatures (s)
    %   .saFeatures (sa)
    %   .actionProbabilities (pi)
    %   .action (a)
    %   .reward (r)
    state, prevState;
    
    % Learning iteration counter. type: int
    actorIteration = 0;
    
  end
  
  
  methods
    
    function this = AgentNaturalActorCritic( critic, varargin )
      % Constructor
      %
      %   'stepsize', (double | 2-element double array) stepsize
      %     Actor stepsize. A scalar stepsize argument defines a constant
      %     stepsize. An array [c, d] defines a schedule of the form:
      %       c / (t + d),
      %     where t is the iteration number (starting from 0).
      %
      %   'theta0', (double array) theta0
      %     Initial policy parameters.
      %
      %   'thetaC', (double) thetaC
      %     Level of enforced explorativity in the main policy. Currently
      %     this has the effect of constaining the 2-norm of theta to
      %     thetaC or below: ||theta||_2 <= thetaC
      
      this.critic = critic;
      
      args = inputParser;
      args.addParamValue( 'stepsize', 1, @(x) (isnumeric(x) && isvector(x) && length(x) <= 2) );
      args.addParamValue( 'theta0', [], @isnumeric );
      args.addParamValue( 'thetaC', Inf, @(x) (isnumeric(x) && isscalar(x)) );
      args.addParamValue( 'beta', 1, @(x) (isnumeric(x) && isscalar(x)) );
      args.addParamValue( 'tau', 1, @(x) (isnumeric(x) && isscalar(x)) );
      args.addParamValue( 'QInterpretation', 'gradient', @ischar );
      args.parse( varargin{:} );
      
      this.stepsize = args.Results.stepsize;
      this.theta0 = args.Results.theta0(:);   % enforce into a column array
      this.thetaC = args.Results.thetaC;
      this.beta = args.Results.beta;
      this.tau = args.Results.tau;
      this.QInterpretation = args.Results.QInterpretation;
      
    end
    
    function this = init( this, varargin )
      this = init@Agent( this, varargin{:} );
      
      % init
      
      % both discrete and continuous spaces are supported, so don't check
      
      % compatible only with actions list based environments
      assert( this.props.useActionsList, 'Compatible only with actions list based environments.' );
      
      % compute state and state-action dimensionality
      this.sDim = this.props.observationDim;
      this.aDim = this.props.actionDim;
      
      % compute critic dimensionality and set it to critic
      this.critic.dim = this.sDim + this.aDim;
      
      % check theta0
      if isempty(this.theta0); this.theta0 = zeros( this.aDim, 1 ); end
      
      
      % reset
      
      % reset the policy
      this.theta = this.theta0;
      
      % reset the actor iteration counter
      this.actorIteration = 0;
      
      % reset the critic
      this.critic = reset( this.critic );
      
    end
    
    function this = newEpisode( this )
      
      this.state = struct( 'sFeatures', [], 'saFeatures', [], 'actionProbabilities', [], 'action', [], 'reward', [] );
      this.prevState = this.state;
      
      this.critic = newEpisode( this.critic );
      
    end
    
    function [this, action] = step( this, reward, sFeatures, saFeatures )
      % Step the agent to the next time intant.
      %
      %   (double) reward
      %     The immediate reward that followed the previous state-action
      %   sFeatures
      %     The current state feature activations. type: row double
      %     array
      %   saFeatures
      %     The actions matrix (rows contain featurizations of each
      %     available action). type: double matrix
      %   (int) action
      %     Index of the selected action: this is a row index into the
      %     saFeatures matrix.
      %
      %   Input features
      %
      %   The state feature vector defines the feature activations for the
      %   current state. This will be used in estimation of the state value
      %   function V. The actionc matrix (state-action feature matrix)
      %   defines the feature activations for the currently available
      %   state-actions. This will be used in estimation of the advantage
      %   function A and the policy parameters theta. There will be critic
      %   parameters for each element of the sFeatures vector, which will
      %   encode state values, and critic parameters for each column of the
      %   saFeatures matrix, which will encode advantages. There will be
      %   actor parameters only for each column of the saFeatures matrix
      %   for encoding action selection probabilities.
      %
      %   Each row of the saFeatures matrix represents an available action:
      %   row i contains the feature activations for action i. See
      %   Environment.getAvailableActions().

      % we require an explicit action list here (check for terminal state)
      if ~isempty(sFeatures); assert( ~isempty(saFeatures) ); end
      
      % keep previous state, state-actions and reward for learning
      this.prevState = this.state;
      this.prevState.reward = reward;   % reward is communicated with a 1-step delay
      
      % step: update the current state and action
      if ~isempty(sFeatures)
        this.state.sFeatures = sFeatures;
        this.state.saFeatures = saFeatures;
        [this.state.actionProbabilities, this.state.action] = decideAction( this, this.state.saFeatures );
      else
        % terminal state
        this.state.sFeatures = []; this.state.saFeatures = [];
        this.state.actionProbabilities = []; this.state.action = [];
      end
      
      % learn if learning is enabled and not the first step
      if this.learning && ~isempty( this.prevState.sFeatures )
        this = learn( this, this.prevState.sFeatures, this.prevState.saFeatures, ...
                      this.prevState.actionProbabilities, this.prevState.action, this.prevState.reward, ...
                      this.state.sFeatures, this.state.saFeatures, this.state.action );
      end
      
      % set the return value
      action = this.state.action;
      
    end
    
    function this = iterateActor( this, stepsize )
      % Perform an actor iteration, then apply forgetting in the critic.
      
      % handle args
      if nargin < 2; stepsize = this.stepsize; end
      
      % handle stepsize scheduling
      if length(stepsize) == 2
        stepsize = stepsize(1) / (this.actorIteration + stepsize(2));
      end
      
      % perform an actor iteration
      switch this.QInterpretation
        case 'gradient'
          % with beta = 1, implements policy gradient iteration
          % with beta = 0, implements non-optimistic (non-gradual) greedy policy iteration (equivalent to CNAC)
          this.theta = this.beta * this.theta + stepsize * getQ(this);
        case 'target'
          % with beta = 1 and alpha in (0,1], implements optimistic
          % (gradual) soft-greedy policy iteration with temperature tau
          this.theta = this.beta * this.theta + stepsize * (getQ(this) - this.theta);
        otherwise
          error('Invalid QInterpretation value: ''%s''', this.QInterpretation );
      end
      
      % CNAC: constrain norm(theta) <= this.thetaC
      this.theta = min( 1, this.thetaC / norm(this.theta) ) * this.theta;
      
      % finalize the critic, then forget critic statistics
      this.critic = finalize( this.critic );
      this.critic = forget( this.critic );
      
      % increment iteration counter
      this.actorIteration = this.actorIteration + 1;
      
    end
    
    
    function V = getV( this )
      
      % update the critic
      this.critic = computeV( this.critic );
      
      % get V and A, return V
      V = this.critic.V(1:this.sDim);
      
    end
    
    function Q = getQ( this )
      
      % update the critic
      this.critic = computeV( this.critic );
      
      % get V and A, return A
      Q = this.critic.V(this.sDim+1:end);
      
    end
    
    function theta = getTheta( this )
      theta = this.theta;
    end
    
    % Return the condition number of the gradient estimate.
    function cnd = getCond( this ); cnd = getCond( this.critic ); end
    
    % Assign a new theta0 (enforce into a column array)
    function this = setTheta0( this, theta0 ); this.theta0 = theta0(:); end
    
    function [this, data] = mexFork( this, useMex )
      [this, data] = mexFork@Agent( this, useMex );
      
      if useMex
        
        data.criticClass = find(strcmp( class(this.critic), {'LSTDLambda', 'LSPELambda', 'FullTDLambda'} )) - 1;
        assert( ~isempty(data.criticClass) );
        
        data.learning = this.learning;
        
        data.theta = this.theta;
        data.gamma = this.critic.gamma;
        data.lambda = this.critic.lambda;
        data.tau = this.tau;
        
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
    
    function [pi, a] = decideAction( this, saFeatures )
      % Decide on an action based on this.theta and the features of
      % available actions that are along the rows of saFeatures.
      
      % compute action probabilities for each row in saFeatures
      pi = (saFeatures * this.theta) / this.tau;
      pi = exp(pi - max(pi));   % avoid overflow
      pi = (pi / sum(pi));
      
      % sample the action
      a = randDiscretePdf( this.rstream, pi );
      
    end
    
    function this = learn( this, phi_s0, phi_sa0, pi0, a0, r0, phi_s1, phi_sa1, a1 )
      % On-policy learning. See (Peters, 2007, Table 4.5).
      %
      %   (row double vector) phi_s0
      %     state feature activations for previous state
      %   (double matrix) phi_sa0
      %     state-action feature activations for previous state-actions
      %   (column double vector) pi0
      %     action probabilities for previous state
      %   (int) a0
      %     action index for previous state
      %   (double) r0
      %     reward for previous state-action
      %   (row double vector) phi_s1
      %     state feature activations for current state
      %   (double matrix) phi_sa1
      %     state-action feature activations for current state-actions
      %   (int) a1
      %     action index for current state
      
      % phi_s1 might be [] if in terminal state, in which case form a zero
      % vector (value of a terminal state is 0)
      if isempty(phi_s1); phi_s1 = zeros(1, this.sDim); end
      

      % gradient vector of the logarithm of the probability of action a0 in
      % state phi_s0:
      %   phi(s,a) - sum_b( pi(b|s) phi(s,b) )
      %
      % phi(s,a) is directly the row a0 of phi_sa0. the sum is the sum of
      % rows in phi_sa0 weighted by pi0.
      grad_log_pi0_a0 = phi_sa0(a0,:)' - phi_sa0' * pi0;
      
      
      % previous state in critic's basis. phi_hat in (Peters, 2007)
      critic_sa0 = [ phi_s0' ; grad_log_pi0_a0(:) ];
      
      % current state in critic's basis. phi_tilde in (Peters, 2007)
      critic_sa1 = [ phi_s1' ; zeros(this.aDim, 1) ];
      
      
      % update critic
      this.critic = step( this.critic, critic_sa0, critic_sa1, r0 );
      
    end
    
  end
  
end
