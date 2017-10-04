classdef EvaluatePolicy < Iterative & Configurable & handle
  %EVALUATEPOLICY Controls policy evaluation iterations
  %
  %   Controls policy evaluation iterations.
  
  
  
  
  properties
    % User-configurable properties
    
    % environment
    environment;
    
    % agent
    agent;
    
    
    % A struct containing conditions for prematurely stopping an episode
    % (or stopping the simulation of a continuing task). An episode is
    % always stopped if the environment runs into a terminal state. Fields:
    %
    %   (int) maxSteps
    %       Maximum number of steps.
    %
    %   (2-element double vector) totalRewardRange
    %       Range [min, max] (inclusive) of allowed total undiscounted
    %       reward. The episode is terminated if total reward exceeds the
    %       range.
    %
    episodeStoppingConditions = struct( 'maxSteps', Inf, 'totalRewardRange', [-Inf, Inf] );
    
    % Whether to use mex implementations. You have to compile them first
    % using make(). type: logical
    useMex = false;
    
    % Whether to print progress information. type: logical
    verbose = true;
    
  end
  
  properties (Hidden, Constant, Access=private)
    SuperclassDefaults = struct( 'iterations', 100 );
  end
  
  
  
  
  methods
    
    
    function this = EvaluatePolicy( name, logger, varargin )
      % Constructs a new policy evaluation process
      %
      %   this = EvaluatePolicy( name, logger, 'iterations', n, <name/value pairs> ... )
      %
      %   (string) name
      %     Name of the iteration process. Used for logging.
      %   (Logger) logger
      %     The Logger object
      %   (int) n
      %     Number of policy evaluation iterations
      %
      % The rest of the parameters (see class properties above) should be
      % provided as name/value pairs here during construction.
      
      % store arguments
      this.name = name;
      this.logger = logger;
      this.configure( [{this.SuperclassDefaults}, varargin] );
      
    end
    
    
    function output = stepHook( this )
      % Run a single evaluation episode (no sub-iteratives are used
      % currently; control is implemented directly here)
      
      % print progress dots
      if this.verbose && mod( this.iteration, ceil(this.iterations/50) ) == 0; fprintf('.'); end
      
      % run one episode
      output = this.runEpisode();
      
    end
    
    
  end
  
  
  
  
  % private methods begin
  
  
  
  
  methods (Access=private)
    
    
    % run the evaluation episodes
    function meanReturn = runEpisode( this )

      % run one episode
      if this.useMex


        % call the mex implementation of the environment-agent pair
        RunEpisodeMex( this.environment, this.agent, this.episodeStoppingConditions );


      else


        % use Matlab implementations

        this.environment.mexFork( false ); this.agent.mexFork( false );

        % inform the environment and the agent about episode start
        [~, observation, actions] = this.environment.newEpisode();
        this.agent.newEpisode();
        reward = 0;

        % run
        totalReward = 0; stepCounter = 0;
        while ~isempty(observation) && ...
            totalReward >= this.episodeStoppingConditions.totalRewardRange(1) && ...
            totalReward <= this.episodeStoppingConditions.totalRewardRange(2) && ...
            stepCounter < this.episodeStoppingConditions.maxSteps

          % agent step
          [~, action] = this.agent.step( reward, observation, actions );

          % environment step
          [~, reward, observation, actions] = this.environment.step( action );

          totalReward = totalReward + reward; stepCounter = stepCounter + 1;
        end

        % provide reward. observation and actions will be empty matrices.
        [~, ~] = this.agent.step( reward, [], [] );

        this.environment.mexJoin( [] ); this.agent.mexJoin( [] );


      end
      
      % pass back the total return
      meanReturn = this.environment.loggerProxy.lastReturn;

    end
    
    
  end
  
  
end
