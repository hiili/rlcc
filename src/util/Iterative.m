classdef Iterative < handle
  %ITERATIVE Define and run an iterative process with automatic logging
  %
  %   Define and run an iterative process with automatic logging. There are
  %   several ways to use the Iterative class. The simplest way is to use
  %   to iterate() convenience wrapper (see iterate.m), which is simply a
  %   short-hand for constructing an Iterative object and calling its run()
  %   method. In both cases, the loop body to be run is provided as a function
  %   handle. It is also possible to derive a custom class from the
  %   Iterative class and to define the loop body by reimplementing the
  %   Iterative.beginHook() and Iterative.stepHook() methods.
  %
  %   As an example, consider the following pseudocode, where 'obj' is a
  %   handle to an 'Obj' object and the Obj.compute() method has both side
  %   effects and returns some result, and 'logs' is an instance of the
  %   Logger class:
  %
  %     logs.log( 'MainLoop', obj );
  %     for i=1:n
  %       y{i} = obj.compute(i, data1, data2);
  %       logs.log( 'MainLoop', obj );
  %     end
  %
  %   With the Iterative class, assuming that 'obj' is a handle object and
  %   that it has been connected to the logger (see the documentation of
  %   the Logger class), this becomes either:
  %
  %     y = iterate( 'MainLoop', logs, n, @(i, d1, d2) obj.compute(i, d1, d2), data1, data2 );
  %
  %   or
  %
  %     y = iterate( 'MainLoop', logs, n, @loopbody, data1, data2 );
  %
  %     function y = loopbody( i, d1, d2 )
  %       y = obj.compute(i, d1, d2);
  %     end
  %
  %   or
  %
  %     it = MyIterative( ... );   % set up and configure a custom
  %                                % Iterative procedure
  %     y = it.run();
  %
  %   It is also possible to run several concurrent iterations:
  %
  %     it1 = MyIterative( ... );
  %     it2 = MyIterative( ... );
  %
  %     y1 = {}; y2 = {};
  %     it1.begin(); it2.begin();
  %     while it1.isRunning() && it2.isRunning()
  %       y1{end+1} = it1.step();
  %       y2{end+1} = it2.step();
  %     end
  %
  %   or just
  %
  %     ...
  %     while it1.voidStep() && it2.voidStep(); end
  %
  %   Nested iterations are also supported, in which case the logs struct
  %   in the Logger object becomes accordingly hierarchical.
  
  % TODO Allow multidimensional iteration (store a vector to 'iterations').
  % Needed by GradientMapper2d.
  
  
  %#ok<*AGROW>
  
  
  properties
    % User-configurable properties
    
    % Name of the Iterative. Used for logging. type: string
    name;
    
    % Logger handle.
    logger;
    
    % Number of iterations. type: int
    iterations = 0;
    
    % Loop body. type: function handle. signature:
    %   output = body( (int) iteration, arguments{:} )
    body;
    
    % Loop body arguments. type: cell array
    arguments;
    
  end
  
  
  properties
    % Properties set by Iterative
    
    % current iteration. type: int
    iteration;
    
  end
  
  
  
  
  methods
    
    
    function this = Iterative( name, logger, iterations, body, varargin )
      % Construct an Iterative object
      %
      %   this = Iterative( name, logger, iterations, [body, arguments ...] )
      %   this = Iterative()
      %
      %   (string) name
      %     Name of the iteration. Used in logging.
      %   (Logger handle) logger
      %     The Logger instance that should record this iteration process.
      %   (int) iterations
      %     Number of iterations.
      %   (function handle) body
      %     Loop body. Handle signature:
      %       output = body( (int) iteration, arguments{:} )
      %   (varargin) arguments
      %     Additional arguments for the loop body function.
      %
      % In the first form, 'body' and 'arguments' can be omitted if the
      % class is extended with a custom implementation of the stepHook()
      % method. Properties can be set also manually after empty
      % construction.
      
      if nargin > 0
        this.name = name;
        this.logger = logger;
        this.iterations = iterations;
        if nargin > 3
          this.body = body;
          this.arguments = varargin;
        end
      end
      
      this.iteration = Inf;   % not running
      
    end
    
    
    function running = isRunning( this )
      % Return true if there are still iterations left after the current
      % iteration. Note that 'false' is returned already during the last
      % iteration.
      running = ( this.iteration < this.iterations );
    end
    
    
    function beginHook( this )                                                                                %#ok<MANU>
      % A hook method that a derived class can reimplement. The method is
      % called from Iterative.begin().
      %
      % Default implementation: no-op
    end
    
    function output = stepHook( this )
      % A hook method that a derived class can reimplement. The method is
      % called from Iterative.step().
      %
      % Default implementation: call 'body' with iteration index and
      % 'arguments'
      
      output = this.body( this.iteration, this.arguments{:} );
      
    end
    
    
    function begin( this )
      % Prepare the object for a new iteration
      
      % initialize counter
      this.iteration = 0;
      
      % call implementation hook
      this.beginHook();
      
    end
    
    function output = step( this )
      % Perform a single iteration step
      
      % check if the iteration has terminated, increment counter
      if ~this.isRunning(); return; end
      this.iteration = this.iteration + 1;
      
      % log
      this.logger.logStepBegin( this );
      
      % call implementation hook
      output = this.stepHook();
      
      % log
      this.logger.logStepEnd( this );
      
    end
    
    function running = voidStep( this )
      % Perform a single iteration with no return value from the loop body.
      % The value from isRunning() is returned in place.
      
      this.step();
      running = this.isRunning();
      
    end
    
    
    function output = run( this )
      % Run all iteration steps at once
      
      output = {};
      this.begin();
      while this.isRunning()
        output{end+1} = this.step();
      end
        
    end
    
    
  end
  
  
end
