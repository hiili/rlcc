classdef AgentOnlineGreedyTD < Agent
  %AGENTONLINEGREEDYTD An on-line greedy temporal difference agent.
  %
  %   Implements either SARSA or Q-learning. Supports linear function
  %   approximation and uses epsilon-greedy exploration. One discrete state
  %   variable and one discrete action variable are allowed and they must
  %   have a range that starts from 1. Alternatively all state dimensions
  %   can be continuous, in which case the state space is interpreted as
  %   the feature space of a linear in parameters function approximator.
  %   Use AgentFltDiscretizer to discretize and/or flatten the state and
  %   action spaces of higher-dimensional environments. Observations are
  %   directly used as state estimates.
  %
  %   NOTE: (edit: might not apply anymore?) The case of a single-parameter
  %   parameterization is not handled properly! (observation becomes
  %   expanded incorrectly)
  
  % TODO: Refactor common code out from AgentTabularNAC and
  % AgentOnlineGreedyTD. (there is a lot!)
  
  
  
  
  properties (Access=private)
    
    % Metaparameters
    gamma;      % discount factor
    lambda;     % eligibility trace decay factor
    alpha;      % learning rate
    epsilon;    % e-greedy exploration rate
    mode;       % 'QLearning' or 'SARSA'
    
    % state, action and state-dependent action counts (observations are
    % used as states)
    sCount, aCount, saCounts;
    
    % whether saCounts is being used
    saCountsOn = true;
    
    
    % Q function
    %   Q(s,a) is the estimated Q value for action a in state s. Elements
    %   outside the saCounts ranges (Q(s,a) for all a > saCounts(s)) are
    %   zero.
    Q;
    
    % eligibility trace
    z;
    
    
    % The previous and current state estimates (s0, s1)
    prevState, state;
    
    % The previous and current actions (a0, a1)
    prevAction, action;
    
    % The previous reward (r)
    prevReward;
    
  end
  
  
  
  
  methods
    
    function this = AgentOnlineGreedyTD( gamma, lambda, alpha, epsilon, mode )
      % Constructor
      %
      %   this = AgentOnlineGreedyTD( gamma, alpha, epsilon, mode )
      %
      % Arguments
      %   (double) gamma
      %       Discount factor. Range: [0,1]
      %   (double) lambda
      %       Eligibility trace decay factor. Range: [0,1]
      %   (double) alpha
      %       Learning rate. Range: [0,1]
      %   (double) epsilon
      %       Exploration parameter for the e-greedy exploration policy.
      %       Range: [0,1]
      %   (string) mode
      %       'QLearning' or 'SARSA'
      
      assert(strcmp( mode, 'QLearning' ) || strcmp( mode, 'SARSA' ));
      
      % store
      this.gamma = gamma;
      this.lambda = lambda;
      this.alpha = alpha;
      this.epsilon = epsilon;
      this.mode = mode;
      
    end
    
    function this = init( this, varargin )
      this = init@Agent( this, varargin{:} );
      
      % require a discrete action space, observation space can be either
      assert( this.props.actionType == 'd' );
      
      % compute state, action and observation-dependent action
      % dimensionality (use observations as states)
      this.sCount = this.props.observationDim;
      this.aCount = this.props.actionDim;
      this.saCounts = this.props.oaRanges';
      if isempty(this.saCounts)
        this.saCounts = repmat( this.aCount, this.sCount, 1 );
        this.saCountsOn = false;
      end
      
      % init the Q function
      this.Q = zeros( this.sCount, this.aCount );
      for s=1:this.sCount
        this.Q(s,1:this.saCounts(s)) = ...
          eps * rand( this.rstream, 1, this.saCounts(s) );
      end
      
    end
    
    function this = newEpisode( this )
      this = newEpisode@Agent( this );
      
      this.prevState = []; this.prevAction = []; this.prevReward =[];
      this.state = []; this.action = [];
      
      this.z = zeros(size(this.Q));
      
    end
    
    function [this, action] = step( this, reward, observation, actions )
      this = step@Agent( this, reward, observation, actions );
      
      observation = observation';   % TODO remove
      
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
        this = learn( this, this.prevState, this.prevAction, ...
          this.prevReward, this.state, this.action );
      end
      
      % set the return value
      action = this.action;
      
    end
    
    
    function Q = getQ( this )
      Q = this.Q(:);
    end
    
    function V = getV( this )
      V = max( this.Q, [], 2 );
    end
    
    function Pi = getPi( this )
      
      % get V function and replicate it along action dim
      Vr = repmat( getV( this )', 1, this.aCount );
      
      % unnormalized action probabilities for the greedy policy
      Pi = double( this.Q == Vr );
      
      % normalize in case of actions with equal value
      Pi = Pi ./ repmat( sum( Pi, 2 ), 1, this.aCount );
      
      % flatten
      Pi = Pi(:);
      
    end
    
  end
  
  
  
  
  % private methods begin
  
  
  
  
  methods (Access=private)
    
    
    function aCount = getActionCount( this, s )
      
      if( this.props.observationType == 'd' )
        aCount = this.saCounts(logical(s));
      else
        assert( ~this.saCountsOn, 'saCounts cannot be used with non-tabular states!' );
        aCount = this.aCount;
      end
      
    end
    
    function values = getQValues( this, s, a )
      values = this.Q(:,a)' * s;
    end
    
    function this = updateQValue( this, sa, delta )
      this.Q = this.Q + delta * sa;
    end
    
    
    function a = decideAction( this, s )
      
      % e-greedy if learning, greedy otherwise
      if this.learning && rand( this.rstream ) < this.epsilon
        a = randomAction( this, s );
      else
        a = greedyAction( this, s );
      end
      
    end
    
    function a = randomAction( this, s )
      % Draw a random action.
      
      a = floor( rand(this.rstream) * getActionCount(this, s) + 1 );
      
    end
    
    function a = greedyAction( this, s )
      % Draw a greedy action. Ties (several actions with exactly equal
      % value) are broken in a stochastic fashion.
      
      % extract action values for actions in the current state
      Qs = getQValues( this, s, 1:getActionCount(this, s) );
      
      % greedy action. permute to break ties in a stochastic manner.
      p = randperm( this.rstream, length(Qs) ); Qs = Qs(p);
      [~, a] = max( Qs );
      a = p(a);
      
    end
    
    
    function this = learn( this, s0, a0, r, s1, a1 )
      % SARSA by default. No eligibility traces, no discounting.
      
      % find the value of s1
      if isempty(s1)
        % terminal state, for which the value is always zero
        Q1 = 0;
      else
        % Q-learning?
        if strcmp( this.mode, 'QLearning' )
          % off-policy: overwrite next action with the greedy action
          a1 = greedyAction( this, s1 );
        end
        
        % extract the Q value
        Q1 = getQValues( this, s1, a1 );
      end
      
      % we now have s0, a0, r, and Q1
      
      % eligibility trace
      sa0 = zeros(size(this.Q)); sa0(:,a0) = s0;
      this.z = this.gamma * this.lambda * this.z + sa0;
      
      % Q delta
      deltaQ = (r + this.gamma * Q1) - getQValues(this, s0, a0);
      
      % update previous state-action towards target
      this = updateQValue( this, this.z, this.alpha * deltaQ );
      
    end
    
    
  end
  
  
end
