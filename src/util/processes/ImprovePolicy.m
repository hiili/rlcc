classdef ImprovePolicy < Iterative & Configurable & handle
  %IMPROVEPOLICY Controls policy improvement iterations
  %
  %   Controls policy improvement iterations.
  
  % TODO Implement line search as a derived class of this, or as an
  % alternative to this.
  
  
  
  
  properties
    % User-configurable properties
    
    % the environment
    environment;
    
    % the agent
    agent;
    
    
    % Environment parameters. These are loaded before each iteration.
    environmentParams = struct();
    
    % Agent parameters. These are loaded before each iteration.
    agentParams = struct();
    
    
    % policy evaluation process object
    evaluation;
    
  end
  
  properties (Constant, Hidden, Access=private)
    SuperclassDefaults = struct( 'iterations', 10 );
  end
  
  
  
  
  methods
    
    
    function set.environment( this, value )
      this.environment = value;
      this.evaluation.environment = this.environment;
    end
    
    function set.agent( this, value )
      this.agent = value;
      this.evaluation.agent = this.agent;
    end
    
    
    function this = ImprovePolicy( name, logger, varargin )
      % Constructs a new policy improvement process
      %
      %   this = ImprovePolicy( name, logger, 'iterations', n, <name/value pairs> ... )
      %
      %   (string) name
      %     Name of the iteration process. Used for logging.
      %   (Logger) logger
      %     The Logger object
      %   (int) n
      %     Number of policy improvement iterations
      %
      % The rest of the parameters (see class properties above) should be
      % provided as name/value pairs here during construction.
      
      % store arguments
      this.name = name;
      this.logger = logger;
      this.configure( [{this.SuperclassDefaults}, varargin] );
      
      % create the policy evaluation process, init with defaults
      this.evaluation = EvaluatePolicy( 'evaluation', this.logger );
      
    end
    
    
    function output = stepHook( this )
      % Run a single training iteration
      
      % run evaluation
      output = this.evaluation.run();
      
      % evaluation episodes completed, time for policy improvement
      if this.agent.learning; this.agent.iterateActor(); end
      
    end
    
    
  end
  
  
end
