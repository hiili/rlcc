classdef AgentQLearningAFW < Agent
    %AGENTQLEARNING A Q-learning agent with no function approximation.
    %   Only one discrete state variable and one discrete action variable
    %   are allowed and they must have a range that starts from 1. Use
    %   AgentFltDiscretizer to discretize and/or flatten the state and
    %   action spaces. Observations are directly used as state estimates.
    
    
    properties (Access=private)
        
        % Metaparameters
        gamma;      % discount factor
        alpha;      % learning rate
        epsilon;    % e-greedy exploration
        
        % state, action and state-dependent action counts (observations are
        % used as states)
        sCount, aCount, saCounts;
        
        
        % Q function
        %   Q(s,a) is the estimated Q value for action a in
        %   state s. Elements outside the saCounts ranges (Q(s,a) for
        %   all a > saCounts(s)) are NaN.
        Q;
        
        
        % The previous and current state estimates (s0, s1)
        prevState, state;
        
        % The previous and current actions (a0, a1)
        prevAction, action;
        
        % The previous reward (r)
        prevReward;
        
    end
    
    
    methods
        
        function this = AgentQLearningAFW( gamma, alpha, epsilon )
            % Constructor
            %
            %   this = AgentQLearning( gamma, alpha, epsilon )
            %
            % Arguments
            %   (double) gamma
            %       Discount factor. Range: [0,1]
            %   (double) alpha
            %       Learning rate. Range: [0,1]
            %   (double) epsilon
            %       Exploration parameter for the e-greedy exploration policy.
            %       Range: [0,1]
            
            % store
            this.gamma = gamma;
            this.alpha = alpha;
            this.epsilon = epsilon;
            
        end
        
        function this = init( this, varargin )
            this = init@Agent( this, varargin{:} );
            
            % only discrete variables allowed. only one state and one
            % action variable allowed.
            assert( this.props.observationDim == 1 && ...
                this.props.actionDim == 1 && ...
                this.props.observationTypes == 'd' && ...
                this.props.actionTypes == 'd' && ...
                this.props.observationRanges(1,1) == 1 && ...
                this.props.actionRanges(1,1) == 1 );
            
            % compute state, action and observation-dependent action
            % dimensionality (use observations as states)
            this.sCount = this.props.observationRanges(1,2);
            this.aCount = this.props.actionRanges(1,2);
            this.saCounts = this.props.oaRanges';
            if isempty(this.saCounts)
                this.saCounts = repmat( this.aCount, this.sCount, 1 );
            end
            
            % init the Q function for the first time
            this = reset( this );
            
        end
        
        function this = reset( this )
            this = reset@Agent( this );
            
            % init the Q function
            this.Q = nan( this.sCount, this.aCount );
            for s=1:this.sCount
                this.Q(s,1:this.saCounts(s)) = ...
                    eps * rand( this.rstream, 1, this.saCounts(s) );
            end
            
        end
    
        function this = newEpisode( this )
            this = newEpisode@Agent( this );
            
            this.prevState = []; this.prevAction = []; this.prevReward =[];
            this.state = []; this.action = [];
            
        end
        
        function [this, action] = step( this, reward, observation, actions )
            this = step@Agent( this, reward, observation, actions );
            
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
        
        function a = decideAction( this, s )
            
            % e-greedy if learning, greedy otherwise
            if this.learning && rand( this.rstream ) < this.epsilon
                a = randomAction( this, s );
            else
                a = greedyAction( this, s );
            end
            
            
        end
        
        function this = learn( this, s0, a0, r, s1, a1 )
            % Q-learning. No eligibility traces, no discounting.
            
            % find the (greedy) value of the end state
            if isempty(s1)
                
                % terminal state, for which the value is always zero
                Q1 = 0;
                
            else
                
                % off-policy
                a1 = greedyAction( this, s1 );
                
                % extract the Q value
                Q1 = s1 .* this.Q(:,a1);
                
            end
            
            % target Q value
            targetQ = r + this.gamma * Q1;
            
            % update previous state-action towards target
            % TODO LMS RULE!
            this.Q(s0,a0) = this.Q(s0,a0) + ...
                this.alpha * ( targetQ - this.Q(s0,a0) );
            
        end
        
        function a = randomAction( this, s )
            
            a = floor( rand(this.rstream) * this.saCounts(s) + 1 );
            
        end
        
        function a = greedyAction( this, s )
            % Ties (several actions with exactly equal value) are broken in a
            % stochastic fashion.
            
            % extract action values for actions in the current state
            Qs = this.Q(s,1:this.saCounts(s));
            
            % greedy action. permute to break ties in a stochastic manner.
            p = randperm( this.rstream, length(Qs) ); Qs = Qs(p);
            [dummy, a] = max( Qs );
            a = p(a);
            
        end
        
    end
    
end
