classdef Trainer < Configurable & Copyable & handle
  %TRAINER Run a single training session on an environment-agent pair.
  %
  %   Runs a single training session on an environment-agent pair. A
  %   training session consists of training iterations and a single test
  %   iteration, both consisting from a number of episodes.
  %
  %   The Trainer object requires a number of parameters to be set. These
  %   parameters are listed at the public properties section below, along
  %   with some default values. The parameters should be provided as
  %   constructor arguments. The training process is started by calling the
  %   method Trainer.run(). Results will be available in the property field
  %   Trainer.results.
  %
  %   See also Experiment
  
  
  %#ok<*PROP,*CTCH>
  
  
  properties
    % User-configurable parameters
    
    % Random seed
    seed = 1;
    
    % Logging level
    %   'episodes'     Log on episode level
    %   'iterations'   Log on iteration level
    %   'none'         Disable logging
    logLevel = 'episodes';
    
    % The environment
    environment;
    
    % The agent
    agent;
    
    % Iteration processes. These are created during construction and can be
    % configured afterwards by the user.
    training; trainingTest; testing;
    
  end
  
  properties
    
    % the logger object
    logger;
    
    % summary of results
    results;
    
  end
  
  
  properties (Access=private)
    
    % random number stream
    rstream;
    
  end
  
  
  
  
  methods
    
    function set.environment( this, value )
      this.environment = value;
      this.training.environment = this.environment;
      this.trainingTest.environment = this.environment;
      this.testing.environment = this.environment;
    end
    
    function set.agent( this, value )
      this.agent = value;
      this.training.agent = this.agent;
      this.trainingTest.agent = this.agent;
      this.testing.agent = this.agent;
    end
    
    
    function this = Trainer( varargin )
      % Construct a new Trainer.
      % 
      %   this = Trainer( <name/value pairs> ... )
      % 
      % The parameters (see user-configurable class properties above) can
      % be provided as name/value pairs here during construction or they
      % can be directly filled in after construction.
      
      % create logger (rules depend on configuration and are thus added in init())
      this.logger = Logger();

      % create the policy improvement and testing processes, init with defaults
      this.training = ImprovePolicy( 'training', this.logger );
      this.trainingTest = ImprovePolicy( 'trainingTest', this.logger, 'iterations', 0 );
      this.testing = EvaluatePolicy( 'testing', this.logger );
      
      % add processes to logger as targets (not used at the moment)
      this.logger.addTargets( ...
        'training', this.training, 'trainingTest', this.trainingTest, ...
        'testing', this.testing );
      
      % apply the provided configuration
      this.configure( varargin );
      
    end
    
    
    function this = run( this )
      % Run the training and process the results
      
      % initialize the object
      this.init();
      
      % run the training processes
      fprintf( 'Running the training iterations:\n' );
      this.training.begin(); this.trainingTest.begin();
      while this.training.isRunning
        
        fprintf( '    %6d/%d ', this.training.iteration + 1, this.training.iterations ); 
        
        % run a training iteration
        this.agent.learning = true;
        this.training.step();
        
        % obtain and print statistics
        try returns = this.logger.logs.training.evaluation.return(end,:); catch; returns = NaN; end
        try returnMean = this.logger.logs.training.return(end); catch; returnMean = NaN; end
        try returnStd = std(bootstrp( 1000, @mean, returns )); catch; returnStd = NaN; end
        try cnd = this.logger.logs.training.evaluation.cond(end,end); catch; cnd = NaN; end
        fprintf( ' (%s, %s; %s)', fmtnum(returnMean), fmtnum(returnStd), fmtnum(cnd) );
        
        if this.trainingTest.iterations > 0 && this.trainingTest.evaluation.iterations > 0
          
          % run a test iteration
          fprintf( '   Testing: ' );
          this.agent.learning = false;
          pushState( this.environment.rstream ); pushState( this.agent.rstream );
          this.trainingTest.step();   % can stop earlier than this.training
          popState( this.environment.rstream ); popState( this.agent.rstream );

          % obtain and print statistics
          try returns = this.logger.logs.trainingTest.evaluation.return(end,:); catch; returns = NaN; end
          try returnMean = this.logger.logs.trainingTest.return(end); catch; returnMean = NaN; end
          try returnStd = std(bootstrp( 1000, @mean, returns )); catch; returnStd = NaN; end
          fprintf( ' (%s, %s)', fmtnum(returnMean), fmtnum(returnStd) );
          
        end
        
        fprintf( '\n' );
        
      end
      
      if this.testing.iterations > 0
        
        % run the testing process
        fprintf( '    Testing: ' );
        this.agent.learning = false;
        pushState( this.environment.rstream ); pushState( this.agent.rstream );
        this.testing.run();
        popState( this.environment.rstream ); popState( this.agent.rstream );

        % obtain and print statistics
        try returns = this.logger.logs.testing.return; catch; returns = NaN; end
        try returnStd = std(bootstrp( 1000, @mean, returns )); catch; returnStd = NaN; end
        fprintf( ' (%s, %s)\n', fmtnum(mean(returns)), fmtnum(returnStd) );
        
      end

      % compute summaries
      this.computeSummaries();
      
      % reset the agent and finalize the logger to save space (relevant with large experiments with minimal logging)
      this.agent.init();
      this.logger.finalize();
      
    end
    
  end
  
  
  
  
  % private methods begin
  
  
  
  
  methods (Access=private)
    
    
    function init( this )
      % Initialize the object. All relevant public property fields should
      % be already set at this point. This method should be called once and
      % only once, before calling run.
      
      this.rstream = RandStream('mt19937ar', 'seed', this.seed );
      
      this.environment.init( 2^32 * rand(this.rstream) );
      this.agent.init( 2^32 * rand(this.rstream), this.environment.getProps() );
      
      % logger configuration
      switch this.logLevel
        
        case 'episodes'

          % environment logging
          this.logger.addRules( 'name', 'return', ...
            'trigger', {'training.evaluation', 'trainingTest.evaluation', 'testing'}, ...
            'target', 'environment', 'command', 'target.loggerProxy.lastReturn' );
          this.logger.addRules( 'name', 'return', ...
            'trigger', {'training', 'trainingTest'}, ...
            'target', 'logger', 'command', {'mean(target.logs.training.evaluation.return(end,:))', ...
                                            'mean(target.logs.trainingTest.evaluation.return(end,:))'} );

          % agent logging
          this.logger.addRules( 'name', {'V', 'Q', 'cond'}, ...
            'trigger', 'training.evaluation', ...
            'target', 'agent', 'command', {'target.getV()', 'target.getQ()', 'target.getCond()'} );
          this.logger.addRules( ...
            'name', {'pi', 'theta'}, ...
            'trigger', 'training', 'interval', '[]', ...
            'target', 'agent', 'command', {'target.getPi()', 'target.getTheta()'} );
        
        case 'iterations'

          % environment logging
          this.logger.addRules( 'name', {'accumulator.rt', 'accumulator.rtt', 'accumulator.t'}, ...
            'trigger', {'training.evaluation', 'trainingTest.evaluation', 'testing'}, ...
            'target', 'environment', 'command', 'target.loggerProxy.lastReturn' );
          this.logger.addRules( 'name', 'return', ...
            'trigger', {'training', 'trainingTest', 'testing'}, 'interval', {'(]', '(]', '(]='}, ...
            'target', 'logger', 'command', {'mean(target.readAccumulator(''rt''))', ...
                                            'mean(target.readAccumulator(''rtt''))', ...
                                            'mean(target.readAccumulator(''t''))'} );
          
          % agent logging
          this.logger.addRules( 'name', {'V', 'Q', 'cond'}, ...
            'trigger', 'training.evaluation', 'interval', '(]=', ...
            'target', 'agent', 'command', {'target.getV()', 'target.getQ()', 'target.getCond()'} );
          this.logger.addRules( ...
            'name', {'pi', 'theta'}, ...
            'trigger', 'training', 'interval', '[]', ...
            'target', 'agent', 'command', {'target.getPi()', 'target.getTheta()'} );
        
        case 'none'
          
        otherwise
          error( 'Unknown logging level ''%s''.', this.logLevel );
      end

      % add targets
      this.logger.addTargets( 'environment', this.environment, 'agent', this.agent );

    end
    
    
    function computeSummaries( this )

      % training
      this.results.returnsTrainIterations = this.logger.logs.training.return;
      this.results.condsTrainIterations = zeros(0,1);
      try this.results.condsTrainIterations = this.logger.logs.training.evaluation.cond(:,end); catch; end
      this.results.returnsTrainEpisodes = zeros(0,1);
      try this.results.returnsTrainEpisodes = this.logger.logs.training.evaluation.return; catch; end

      % trainingTest
      this.results.returnsTrainTestIterations = zeros(0,1);
      this.results.returnsTrainTestEpisodes = zeros(0,1);
      try this.results.returnsTrainTestIterations = this.logger.logs.trainingTest.return; catch; end
      try this.results.returnsTrainTestEpisodes = this.logger.logs.trainingTest.evaluation.return; catch; end

      % testing
      this.results.returnsTestEpisodes = zeros(0,1);
      try this.results.returnsTestEpisodes = this.logger.logs.testing.return; catch; end

    end
    
    
  end


end
