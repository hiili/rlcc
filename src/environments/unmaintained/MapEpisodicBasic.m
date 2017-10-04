classdef MapEpisodicBasic < Environment
    %MAPEPISODICBASIC Basic episodic map-world environment.
    %
    %   WARNING: Not finished nor maintained!
    %
    %   A simple episodic map world similar to the puddle world of
    %   rl-library, except that the state and action spaces are continuous.
    %   All episodes start from the left edge of the map and end at the
    %   right edge. Each time step moves the agent a fixed amount in its
    %   current direction. The agent's direction can be between
    %   [-pi/4,pi/4] (in radians), 0 pointing to right. The environment is thus
    %   deterministic episodic with a varying, finite (and relatively
    %   short) episode length. The action space is 1-dimensional and
    %   continuous with the range [-1,1], with the meaning of adjusting the
    %   current direction: -1 adjusts it towards negativity with some
    %   maximum speed of change, and 1 adjusts it towards positivity. The
    %   scaling and thus the maximum speed of change is determined by a
    %   hard-wired constant (currently 0.01).
    %
    %   Observation space
    %       3 dimensional continuous:
    %           x position: [0,1]
    %           y position: [0,1]
    %           direction: [-pi/4,pi/4]
    %       (0,0,0) is at the bottom left corner, facing right. positive
    %       directions are upwards.
    %
    %   Action space
    %       1 dimensional continuous, range: [-1, 1]
    %           1: adjust direction counter-clockwise (upwards) with
    %           maximum rate of change
    %           0: no direction adjustment
    %           -1: adjust direction clockwise (downwards) with maximum
    %           rate of change
    %
    %   Reward
    %       Sum of Gaussian radial functions located within the grid. See
    %       constructor documentation for details on configuring the
    %       functions.
    %
    %   Start distribution
    %       Position is from a Gaussian along the left edge, center in the
    %       middle, stddev = 1/4. Initial direction is 0 (straight towards
    %       right). No configurable parameters.
    %
    %   Terminal conditions
    %       An episode ends when the agent moves beyond the right edge.
    %       Episode ends if the next observation would be: (the agent won't
    %       see this observation)
    %           observation(1) > 1
    %       The agent starts always from the left edge and each step moves
    %       it towards the right edge. The world is episodic with a
    %       varying, finite (and relatively short) episode length with no
    %       recurrent states.
    %
    %   Dynamics
    %       Deterministic dynamics.
    
    
    properties   % inherited (and constant in practice)
        
        props;
        
    end
    
    properties (Constant, Access=private)
        
        rewardFuncNames = { ...
            'middlepuddle', 'sidepuddles' };
        
        rewardFuncs = { ...
            @rewardsMiddlepuddle, @rewardsSidepuddles };
        
    end
    
    properties (Access=private)
        
        % stepsize (see constructor documentation)
        stepsize;
        
        % Function pointer to the selected reward function
        rewardFunc;
        
        % (sruct) state
        % Fields:
        %
        %   (2-element double vector) pos
        %       Current (x,y) position of the agent. (0,0) is at the lower
        %       left corner.
        %
        %   (double) dir
        %       Current direction in radians. Range: [-pi/4,pi/4]. 0 is
        %       right, positive is upwards and negative is downwards.
        %
        %   (N-element double vector) vectorialState
        %       Cached vectorial form of the state.
        %
        %   (N-element double vector) observation
        %       Cached observation vector generated for the state.
        state;
        
    end
    
    
    methods
        
        % Constructor
        %
        %   this = MapBasicEpisodic( seed, rewards )
        %
        % Arguments
        %   seed
        %       Random seed. This is passed directy to RandStream.
        %   (double) stepsize
        %       Step length, range: (0,1). Agent position will change
        %       by the amount of 'stepsize' in the current direction.
        %       Maximum steering adjustment is equal to
        %           'stepsize * pi'.
        %       For example, with a stepsize of 0.01, it takes 100 steps
        %       to complete the episode if going straight to the right, and
        %       it takes 50 steps to adjust the direction from one extreme
        %       to the other (distance between extremes is pi/2).
        %   (string) rewards
        %       One of the reward configuration names listed below:
        %           'middlepuddle'
        %               One Gaussian located in the middle of the map.
        %               Reward at the center = -1, stddev = 0.1
        %           'sidepuddles'
        %               Two Gaussians located in the middle of the top and
        %               bottom edges. Reward at the center = -1, stddev =
        %               0.1 grid units.
        %           'zigzag'
        %               ...
        %           'sharp-soft'
        %               ...
        function this = MapEpisodicBasic( stepsize, rewards )
            
            this.props.observationDim = 3;
            this.props.observationTypes = ('ccc')';
            this.props.observationRanges = ...
                [ 0, 1 ; 0, 1 ; -pi/4, pi/4 ];
            this.props.actionDim = 1;
            this.props.actionTypes = ('c')';
            this.props.actionRanges = [-1, 1];
            
            this.stepsize = stepsize;
            
            % set the reward function
            this.rewardFunc = this.rewardFuncs{ ...
                strcmp( rewards, this.rewardFuncNames ) };
            assert( isscalar( this.rewardFunc ), ...
                ['Invalid reward configuration name: ' rewards] );
            
        end
        
    end
    
    
    % protected methods begin (implementations of abstract methods)
    
    
    methods (Access=protected)
        
        % reset the internal state ('state' field)
        function this = resetState( this )
            
            % Gaussian along the left edge,
            % center in the middle, stddev = 1/4
            newX = 0;
            newY = -1;
            while newY < 0 || newY > 1
                newY = 0.5 + (1 / 4) * randn( this.rstream );
            end
            
            this.state.pos = [newX, newY];
            this.state.dir = 0;
            
        end
        
        
        % ---- adapted upto here! ----
        
        
        function this = advanceState( this, action )
            
            % adjust direction and clamp
            this.state.dir = max( -pi/4, min( pi/4, ...
                this.state.dir + this.stepsize * pi * action(1) ));
            
            % update position and clamp vertical
            this.state.pos(1) = this.state.pos(1) + ...
                this.stepsize * cos(this.state.dir);
            this.state.pos(2) = max( 0, min( 1, ...
                this.state.pos(2) + this.stepsize * sin(this.state.dir) ));
            
        end
        
        function ended = checkEndCondition( this )
            ended = ( this.state.pos(1) > 1 );
        end
        
        function stateVec = generateVectorialState( this )
            stateVec = [ this.state.pos, this.state.dir ];
        end
        
        function observation = generateObservation( this )
            observation = [ this.state.pos, this.state.dir ];
        end
        
        function reward = generateReward( this, action )
            reward = feval( this.rewardFunc, this, action );
        end
        
    end
    
    
    % private methods begin
    
    
    methods (Access=private)
        
        % Gaussian radial function, located in the middle of the map,
        % stddev = 1/4. Reward = -1 at the middle of the Gaussian.
        function reward = rewardsMiddlepuddle( this, action )
            
            center = [0.5, 0.5]; stddev = 1/4;
            
            r2 = sum( (this.state.pos - center) .^ 2 );
            reward = -1 * exp( -0.5 * (1/stddev^2) * r2 );
            
        end
        
    end
    
    
    % public methods for analysis and visualization begin
    
    
    methods
        % Return some statistics of the given trajectories.
        %
        % (struct) stats
        % Fields:
        %   (int) nSteps
        %       Total number of steps contained in the data.
        %   (double matrix) sd
        %       Normalized state visitation distribution. sd(x+1,y+1) is
        %       the visit count of state (x,y) divided by the total number
        %       of steps (state visits).
        %   (double matrix) return
        %       Average total reward from the tails of trajectories going
        %       out from a state. return(x+1,y+1) is the average total
        %       return for state (x,y).
        %       NOTE: multiple visits to the same state during a trajectory
        %             are not computed correctly!
        %       NOTE2: states with no visits at all will have a NaN
        %              as the total reward estimate.
        function stats = getStats( this, trajectories )
            
            stats.nSteps = [];
            
            % compute the state visitation distribution
            % (remember: states start from 0!)
            allStatesInds = cat( 1, trajectories.states ) + 1;
            stats.sd = zeros( this.gridSize );
            for ind=allStatesInds'
                stats.sd(ind(1),ind(2)) = stats.sd(ind(1),ind(2)) + 1;
            end
            stats.nSteps = size(allStatesInds, 1);
            stats.sd = stats.sd / stats.nSteps;
            
            % compute returns
            stats.return = zeros( this.gridSize );
            for t=trajectories
                
                % compute returns over the trajectory
                % NOTE: multiple visits do not count correctly!
                returns = cumsum( t.rewards(end:-1:1) );
                returns = returns(end:-1:1);
                statesInd = sub2ind( size(stats.return), ...
                    t.states(:,1)+1, t.states(:,2)+1 );
                stats.return( statesInd ) = stats.return( statesInd ) + ...
                    returns;
                
            end
            stats.return = stats.return ./ (stats.sd * stats.nSteps);
            
        end
        
        
        % Visualize everything.
        %
        %   visualize( this, [trajectoryInds] )
        function visualize( this, trajectoryInds )
            
            if nargin < 2; trajectoryInds=1:8; end
            trajectoryInds( trajectoryInds > length(this.logs) ) = []; 
            
            % init the plot
            clf; subplot(2,1,1); hold on; subplot(2,1,2); hold on;
            
            % visualize overall stats and some trajectories
            if ~isempty(this.logs)
                visualizeStats( this, this.logs );
                subplot(2,1,1);
                visualizeTrajectories( this, this.logs(trajectoryInds) );
                subplot(2,1,2);
                visualizeTrajectories( this, this.logs(trajectoryInds) );
            end
            
            % visualize the environment
            subplot(2,1,1); visualizeEnvironment( this );
            subplot(2,1,2); visualizeEnvironment( this );
            
        end
        
        % Visualize the environment (costs as contour plots)
        function visualizeEnvironment( this )
            
            contour( 0:this.gridSize(1)-1, 0:this.gridSize(2)-1, ...
                this.rewards', 'Color', [0.5 0.5 0.5] );
            
            axis([ -0.5 this.gridSize(1)-0.5 -0.5 this.gridSize(2)-0.5 ]);
            
        end
        
        % Visualize statistics.
        %
        %   (struct array / struct) data
        %       A struct array of trajectories (as in 'logs') or a stats
        %       struct from getStats().
        %
        %   State visitation distribution
        %       The state visitation distribution is visualized as a 2d
        %       image with logarithmic intensity scale.
        function stats = visualizeStats( this, data )
            
            % is 'data' an array of trajectories or a stats struct?
            if ~isfield( data, 'sd' )
                stats = getStats( this, data );
            else
                stats = data;
            end
            
            subplot(2,1,1);
            imagesc( 0:this.gridSize(1)-1, 0:this.gridSize(2)-1, ...
                stats.sd', [0, max(stats.sd(:))] );
            axis xy; colormap hot; colorbar;
            title('state visitation distribution');
            
            subplot(2,1,2);
            imagesc( 0:this.gridSize(1)-1, 0:this.gridSize(2)-1, ...
                stats.return', ...
                [min(stats.return(:)), max(stats.return(:))] );
            axis xy; colormap hot; colorbar;
            title('average return');
            
        end
        
        % Plots the states and transitions of the given trajectories.
        function visualizeTrajectories( this, trajectories )
            
            prevhold = ishold; if ~prevhold; clf; end; hold on
            
            for trajectory=trajectories
                
                plot( trajectory.states(:,1), trajectory.states(:,2), ...
                    'o', 'Color', [0 0.8 1] );

                statediff = diff( trajectory.states, 1, 1 ) .* 0.75 ;
                if ~isempty( statediff )
                    quiver( ...
                        trajectory.states(1:end-1,1), ...
                        trajectory.states(1:end-1,2), ...
                        statediff(:,1), statediff(:,2), 0, ...
                        'Color', [0 0.8 1] );
                end
                
            end
            
            axis([ -0.5 this.gridSize(1)-0.5 -0.5 this.gridSize(2)-0.5 ]);
            if prevhold; hold on; else hold off; end
            
        end
        
    end
    
end
