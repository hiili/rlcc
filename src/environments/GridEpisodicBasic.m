classdef GridEpisodicBasic < Environment
  %GRIDEPISODICBASIC Basic episodic grid-world environment.
  %
  %   State space
  %     2-dimensional integer, ranges: [0, sizeX-1], [0, sizeY-1] (0,0) is
  %     at the bottom left corner.
  %
  %   Observation space
  %     sizeX * sizeY -dimensional discrete, encoded from the state in
  %     row-major order (i.e., the state (0,5) maps to the 6th
  %     observation element).
  %
  %   Action space
  %     3-dimensional discrete
  %       1: move right and down
  %       2: move right
  %       3: move right and up
  %
  %   Reward
  %     Sum of radial Gaussian functions located within the grid. See
  %     constructor documentation for details on configuring the functions.
  %
  %   Start distribution
  %     Gaussian along the leftmost column, center in the middle, stddev =
  %     height/4. No configurable parameters.
  %
  %   Terminal conditions
  %     An episode ends after the agent steps right from the rightmost
  %     column. Episode will end after:
  %       observation(1) = sizeX-1, action = any
  %     The agent starts always from the leftmost column and each action
  %     takes it one step closer to the rightmost column. The world is thus
  %     episodic with a constant episode length:
  %       nSteps = sizeX
  %
  %   Dynamics
  %     Deterministic dynamics. Each time step takes the agent one step to
  %     the right and optionally one step up or down, depending on the
  %     agent's action.
  
  
  
  
  properties (Constant, Access=private)
    
    rewardFuncNames = { 'middlepuddle', ...
                        'sidepuddles', ...
                        'sidepuddles_endwall' };
    
    rewardFuncs = { @rewardsMiddlepuddle, ...
                    @rewardsSidepuddles, ...
                    @rewardsSidepuddlesEndwall };
    
  end
  
  
  properties (Access=protected)
    
    % 2-element array: horizontal (x) and vertical (y) number of grid
    % cells.
    gridSize;
    
    % (double matrix) rewards
    %   Immediate rewards for each grid cell. rewards(x+1,y+1) is the
    %   immediate reward associated with state (x,y) (the reward delivered
    %   after an action in state (x,y)).
    rewards;
    
    % (2-element row int array) state
    %   Current (x,y) position of the agent. Counting starts from 0 and
    %   (0,0) is at the lower left corner.
    state;
    
    % reward for the last transition
    reward;
    
  end
  
  
  properties (Access=private)
    
    % environment properties
    props;
    
    % state visitation distribution
    svd;
    
  end
  
  
  
  
  methods
    
    function this = GridEpisodicBasic( sizeX, sizeY, rewards )
      % Constructor
      %
      %   this = GridBasicEpisodic( sizeX, sizeY, rewards )
      %
      % Arguments
      %   (int) sizeX, sizeY
      %     Grid size.
      %   (string) rewards
      %     One of the following reward configuration names:
      %       'middlepuddle'
      %         One Gaussian located in the middle of the grid. The location
      %         is rounded downwards if necessary to make it coincide with a
      %         grid cell. Reward at the center = -1, stddev = 1 grid units.
      %       'sidepuddles'
      %         Two Gaussians located horizontally in the middle of the grid
      %         and vertically on the top and bottom rows. The locations are
      %         rounded downwards if necessary to make them coincide with a
      %         grid cell. Reward at the center = -1, stddev = 1 grid units.
      %       'sidepuddles_endwall'
      %         As 'sidepuddles', but has a wall almost at the right end.
      %         This makes it impossible to get away by paying attention only
      %         to the immediate rewards.
      %       'zigzag' (not implemented)
      %         ...
      %       'sharp-soft' (not implemented)
      %         ...
      
      assert( isscalar( sizeX ) && isscalar( sizeY ) && isnumeric( sizeX ) && isnumeric( sizeY ) && ...
              isreal( sizeX ) && isreal( sizeY ) && sizeX >= 2 && sizeY >= 1 );
      
      this.props.observationType = 'd';
      this.props.actionType = 'd';
      this.props.observationDim = sizeX * sizeY;
      this.props.actionDim = 3 * this.props.observationDim;
      this.props.useActionsList = true;
      
      this.gridSize = [sizeX, sizeY];
      
      % select the reward function
      rewardFunc = this.rewardFuncs{ strcmp( rewards, this.rewardFuncNames ) };
      assert( isscalar( rewardFunc ), ['Invalid reward configuration name: ' rewards] );
      
      % precompute the reward function
      this.rewards = feval( rewardFunc, this, zeros(this.gridSize) );
      
    end
    
    function this = init( this, varargin )
      this = init@Environment( this, varargin{:} );
      
      % reset statistics
      this.resetStats();
      
    end
    
    % return the environment properties struct
    function props = getProps( this ); props = this.props; end
    
    function resetStats( this )
      % reset statistics
      this.svd = zeros(this.gridSize);
    end
    
    function stats = getStats( this )
      % get statistics
      stats.svd = this.svd / sum(this.svd(:));
    end
    
  end
  
  
  
  
  % protected methods begin (implementations of abstract methods)
  
  
  
  
  methods (Access=protected)
    
    function actions = getAvailableActions( this )
      
      actions = sparse( 3, 3 * prod(this.gridSize) );
      for a=1:3
        actions( a, (a-1)*prod(this.gridSize)+1 : a*prod(this.gridSize) ) = this.observation;
      end
      
    end
    
    function this = resetState( this )
      % reset the internal state ('state' field)
      
      this.reward = 0;
      
      % Gaussian along the left edge,
      % center in the middle, stddev = height/4
      newX = 0;
      newY = -1;
      while newY < 0 || newY > this.gridSize(2) - 1
        newY = floor( this.gridSize(2) / 2 + (this.gridSize(2) / 4) * randn( this.rstream ));
      end
      
      this.state = [newX, newY];
      
    end
    
    function this = advanceState( this, action )
      
      % add old state to svd
      this.svd(this.state(1)+1,this.state(2)+1) = this.svd(this.state(1)+1,this.state(2)+1) + 1;
      
      % add reward
      this.reward = this.rewards( this.state(1)+1, this.state(2)+1 );
      
      % move right
      this.state(1) = this.state(1) + 1;
      
      % possibly move up or down
      switch action
        case 1
          this.state(2) = this.state(2) - 1;
        case 2
          this.state(2) = this.state(2) + 0;
        case 3
          this.state(2) = this.state(2) + 1;
      end
      
      % prevent top or bottom edge overruns
      this.state(2) = max( 0, min( this.gridSize(2) - 1, this.state(2) ));
      
    end
    
    function ended = checkEndCondition( this )
      ended = ( this.state(1) >= this.gridSize(1) );
    end
    
    function stateVec = generateVectorialState( this )
      stateVec = this.state;
    end
    
    function observation = generateObservation( this )
      observation = sparse(1, prod(this.gridSize));
      observation( this.state(2) * this.gridSize(1) + this.state(1) + 1 ) = 1;
    end
    
    function reward = generateReward( this )
      reward = this.reward;
    end
    
  end
  
  
  
  
  % private methods begin
  
  
  
  
  methods (Access=private)
    
    
    function rewards = rewardsMiddlepuddle( this, rewards )
      % Gaussian radial function with h/8 standard deviation, where h is the
      % grid height, located in the middle of the grid (location is rounded
      % down if necessary to make it coincide with a grid cell). Reward = -1
      % at the middle of the Gaussian.
      
      rewards = rewardsGaussianRadial( this, rewards, ...
                                       floor( (this.gridSize - 1) ./ 2 ), ...
                                       this.gridSize(2) / 8, ...
                                       -1 );
      
    end
    
    function rewards = rewardsSidepuddles( this, rewards )
      % Gaussian radial functions with h/8 standard deviation, where h is the
      % grid height, located in the middle of the top and bottom edges
      % (location is rounded down if necessary to make it coincide with a
      % grid cell). Reward contribution = -1 at the middle of the Gaussians.
      
      centerX = floor( (this.gridSize(1) - 1) / 2 );
      
      rewards = rewardsGaussianRadial( this, rewards, ...
                                       [centerX, 0], this.gridSize(2) / 8, ...
                                       -1 );
      
      rewards = rewardsGaussianRadial( this, rewards, ...
                                       [centerX, this.gridSize(2) - 1], this.gridSize(2) / 8, ...
                                       -1 );
      
    end
    
    function rewards = rewardsSidepuddlesEndwall( this, rewards )
      % As rewardsSidepuddles, but adds a wall almost to the end.
      
      wallX = this.gridSize(1) - 2;   % one step left from rightmost column
      wallY1 = 1; wallY2 = this.gridSize(2) - 2;   % leave 1-cell routes at top and bottom
      
      rewards = rewardsSidepuddles( this, rewards );
      rewards = rewardsStep( this, rewards, wallX, wallY1, wallX, wallY2, -1 );
      
    end
    
    function rewards = rewardsGaussianRadial( this, rewards, center, stddev, centerReward )
      % Add a gaussian radial function to the reward table.
      
      % compute squared distances from center
      r2x = ( (0:this.gridSize(1)-1) - center(1) ) .^ 2;
      r2y = ( (0:this.gridSize(2)-1) - center(2) ) .^ 2;
      r2 = repmat( r2x', 1, length(r2y) ) + repmat( r2y, length(r2x), 1 );
      
      % compute and add rewards
      rewards = rewards + centerReward * exp( -0.5 * (1 / stddev^2) * r2 );
      
    end
    
    function rewards = rewardsStep( this, rewards, x1, y1, x2, y2, insideReward )
      % Add a step function to the reward table.
      
      rewards(x1+1:x2+1,y1+1:y2+1) = rewards(x1+1:x2+1,y1+1:y2+1) + insideReward;
      
    end
    
    
  end
  
  
  
  
  % public methods for analysis and visualization begin
  
  
  
  
  methods
    
    
%     function stats = getStats( this, trajectoryInds )
%     % Return some statistics of the selected logged trajectories. If no
%     % trajectory inds are given, then all trajectories will be used.
%     %
%     % (struct) stats
%     % Fields:
%     %   (int) nSteps
%     %     Total number of steps contained in the data.
%     %   (double matrix) sd
%     %     Normalized state visitation distribution. sd(x+1,y+1) is the
%     %     visit count of state (x,y) divided by the total number of steps
%     %     (state visits).
%     %   (double matrix) return
%     %     Average total reward from the tails of trajectories going out
%     %     from a state. return(x+1,y+1) is the average total return for
%     %     state (x,y).
%     %     NOTE: multiple visits to the same state during a trajectory
%     %           are not computed correctly!
%     %     NOTE2: states with no visits at all will have a NaN
%     %            as the total reward estimate.
%     %   (double vector) returns
%     %       Returns for each trajectory.
%       
%       logs = getLogs(this);
%       
%       % if no trajectory inds are given, then use all
%       if nargin < 2; trajectoryInds = 1:logs.episode(end); end
%       
%       tSteps = false( length(logs.episode), 1 );
%       for tInd=trajectoryInds
%         tSteps = tSteps | (logs.episode == tInd);
%       end
%       
%       % compute the state visitation distribution
%       % (remember: states start from 0!) (try to tolerate possible extra
%       % dimensions)
%       allStatesInds = logs.states(tSteps,:) + 1;
%       stats.sd = zeros( this.gridSize );
%       for ind=allStatesInds'
%         stats.sd(ind(1),ind(2)) = stats.sd(ind(1),ind(2)) + 1;
%       end
%       stats.nSteps = size(allStatesInds, 1);
%       stats.sd = stats.sd / stats.nSteps;
%       
%       % compute returns
%       stats.return = zeros( this.gridSize );
%       stats.returns = zeros( 1, length(trajectoryInds) );
%       for t=1:length(trajectoryInds)
%         
%         tInd = trajectoryInds(t);
%         
%         tStates = logs.states(logs.episode == tInd,:);
%         tRewards = logs.rewards(logs.episode == tInd,:);
%         
%         % compute returns over the trajectory
%         % NOTE: multiple visits do not count correctly!
%         returns = cumsum( tRewards(end:-1:1) );
%         returns = returns(end:-1:1);
%         statesInd = sub2ind( size(stats.return), tStates(:,1)+1, tStates(:,2)+1 );
%         stats.return( statesInd ) = stats.return( statesInd ) + returns;
%         
%         % compute overall return statistics
%         stats.returns(t) = sum( tRewards );
%         
%       end
%       stats.return = stats.return ./ (stats.sd * stats.nSteps);
%       
%     end
    
    
%     function visualize( this, trajectoryInds )
%     % Visualize everything.
%       
%       logs = getLogs(this);
%       if nargin < 2; trajectoryInds=1:8; end
%       trajectoryInds( trajectoryInds > logs.episode(end) ) = [];
%       
%       % init the plot
%       clf; subplot(2,1,1); hold on; subplot(2,1,2); hold on;
%       
%       % visualize overall stats and some trajectories
%       if ~isempty(logs.episode)
%         visualizeStats( this );
%         subplot(2,1,1);
%         visualizeTrajectories( this, trajectoryInds );
%         subplot(2,1,2);
%         visualizeTrajectories( this, trajectoryInds );
%       end
%       
%       % visualize the environment
%       subplot(2,1,1); visualizeEnvironment( this, false );
%       subplot(2,1,2); visualizeEnvironment( this, false );
%       
%     end
    
    function visualizeEnvironment( this, fill )
      % Visualize the environment (costs as contour plots)
      %
      %   visualizeEnvironment( this, [fill] )
      %
      % (logical) fill
      %   If true or omitted, then draw a filled reward map. If false, then
      %   draw an unfilled countour plot.
      
      if nargin < 2; fill = true; end
      
      if fill
        imagesc( 0:this.gridSize(1)-1, 0:this.gridSize(2)-1, this.rewards', minmax(this.rewards(:)') );
        axis xy; colormap hot; colorbar;
      else
        contour( 0:this.gridSize(1)-1, 0:this.gridSize(2)-1, this.rewards', 'Color', [0.5 0.5 0.5] );
        axis([ -0.5 this.gridSize(1)-0.5 -0.5 this.gridSize(2)-0.5 ]);
      end
      
    end
    
%     function stats = visualizeStats( this, stats )
%     % Visualize statistics.
%       
%       % is 'data' omitted or a stats struct?
%       if nargin < 2; stats = getStats( this ); end
%       
%       subplot(2,1,1);
%       imagesc( 0:this.gridSize(1)-1, 0:this.gridSize(2)-1, stats.sd', [0, max(stats.sd(:))] );
%       axis xy; colormap hot; colorbar;
%       title('state visitation distribution');
%       
%       subplot(2,1,2);
%       imagesc( 0:this.gridSize(1)-1, 0:this.gridSize(2)-1, stats.return', ...
%                [min(stats.return(:)), max(stats.return(:))] );
%       axis xy; colormap hot; colorbar;
%       title('average return');
%       
%     end
%     
%     function visualizeTrajectories( this, trajectoryInds )
%     % Plots the states and transitions of the specified trajectories.
%       
%       logs = getLogs(this);
%       if nargin < 2; trajectoryInds=1:8; end
%       trajectoryInds( trajectoryInds > logs.episode(end) ) = [];
%       
%       prevhold = ishold; if ~prevhold; clf; end; hold on
%       
%       for tInd=trajectoryInds
%         
%         tSteps = find( logs.episode == tInd );
%         
%         plot( logs.states(tSteps,1), logs.states(tSteps,2), 'o', 'Color', [0 0.8 1] );
%         
%         statediff = diff( logs.states(tSteps,:), 1, 1 ) .* 0.75 ;
%         if ~isempty( statediff )
%           quiver( logs.states(tSteps(1:end-1),1), logs.states(tSteps(1:end-1),2), ...
%                   statediff(:,1), statediff(:,2), 0, 'Color', [0 0.8 1] );
%         end
%         
%       end
%       
%       axis([ -0.5 this.gridSize(1)-0.5 -0.5 this.gridSize(2)-0.5 ]);
%       if prevhold; hold on; else hold off; end
%       
%     end
%     
%     function visualizePolicy( this, agent, nSamples )
%     % Visualize a policy.
%       
%       % NOTE (esp. if translating eg into C++): the environment and the
%       % agent are modified but _not_ returned!
%       
%       % sample averaging is not currently implemented
%       assert( nSamples == 1 );
%       
%       % disable learning
%       agent = setLearning( agent, false );
%       
%       % init transition variables
%       [x0,y0] = ndgrid( 0:this.gridSize(1)-1, 0:this.gridSize(2)-1 );
%       x1d = zeros( this.gridSize );
%       y1d = zeros( this.gridSize );
%       
%       % sweep through the state space
%       for i=1:length(x0(:))
%         
%         % set state and sample the action
%         this = resetState( this );  % in case of a derived obj
%         this.state = [x0(i), y0(i)];
%         [~, action] = step( agent, 0, generateObservation( this ) );
%         
%         % make transition and store relative end state
%         this = advanceState( this, action );
%         x1d(i) = this.state(1) - x0(i);
%         y1d(i) = this.state(2) - y0(i);
%         
%       end
%       
%       % draw
%       quiver( x0, y0, x1d, y1d, 0.5, 'Color', [0 0.8 1] );
%       axis([ -0.5 this.gridSize(1)-0.5 -0.5 this.gridSize(2)-0.5 ]);
%       
%     end
    
    
  end
  
  
end
