classdef Logger < Configurable & handle
  %LOGGER Provides logging functionality
  %
  %   Provides logging functionality. The Logger object can be configured
  %   to pull and store certain data from certain target objects whenever
  %   certain events occur. Logging rules are added with the method
  %   addRules(). The target (handle) objects are associated with the
  %   logger using the method addTargets(). It is also possible to set the
  %   corresponding fields manually or via the Configurable base class.
  %
  %   Logging is triggered by iteration events from Iterative objects. Each
  %   call to the step() method of an Iterative triggers a logging event.
  %   Whether logging occurs depends on the rules (see the 'schema'
  %   property below).
  %
  %   Logs are stored as a struct in the 'logs' property of the Logger
  %   object. The field names in the log correspond to the schema entry
  %   names. Nested iterations are logged as nested structs. The content of
  %   the field depends on the chosen logMode in the logging rule. If
  %   logMode == 'numeric', then the field contains a double array:
  %     log.<name>(...,parent.index,index,:,:,...) = data
  %   If logMode == 'cell', then the field contains a hierarchical cell
  %   array:
  %     logs.<name>{...}{parent.index}{index} = data
  %   If logMode == 'none', then no logging is performed and the command is
  %   evaluated without output arguments.
  %
  %
  % Summarized logging (accumulators)
  %
  %   To save space, it is possible to perform summarization of the logged
  %   values on the fly. This can be accomplished in two steps:
  %     1. Define the main read-out rule (faster time-scale) and add the
  %        prefix 'accumulator.' to the rule name. Do not use subsequent
  %        dots in the rule name.
  %     2. Define the summarizing rule (slower time-scale) and use the rule
  %        name that you want to represent the summarized values in the
  %        logs. Set the Logger object as the target using the preset
  %        target name 'logger'. Then define the command so as to use the
  %        Logger method readAccumulator() to pull out the accumulated
  %        data and to perform summarization of the obtained data. The
  %        accumulator log will be cleared automatically after each
  %        readAccumulator() call. The endpoint mode must not be set to
  %        '[]' or '[)'.
  % 
  %   Example:
  %
  %     rule_acc.name     = 'accumulator.temp'
  %     rule_acc.trigger  = (some faster timescale trigger)
  %     rule_acc.target   = (actual target)
  %     rule_acc.command  = (read fast data from target)
  %     
  %     rule_main.name    = 'foo'
  %     rule_main.trigger = (some slower timescale trigger)
  %     rule_main.target  = 'logger'
  %     rule_main.command = 'mean( target.readAccumulator(''temp'') )'
  %
  %
  % Progress output using the Logger class
  %
  %   It is possible to use the Logger class also for printing progress
  %   output. This can be done by defining a logging rule with a suitable
  %   trigger and including progress printing functions (e.g., fprintf)
  %   into the rule command string. Actual logging can be inhibited by
  %   setting logMode to 'none'.
  %
  %   Logging rules are executed in the order in which they were added. To
  %   use data recorded by another rule during the same event, be sure to
  %   add the progress output rule after the logging rule that it depends
  %   on.
  
  % PLAN Logging of tight inner loops and mex functions
  %
  %   It is certainly too slow to log from tight inner loops using the full
  %   logging mechanism. In such cases, some aggregated statistic should
  %   be computed manually within the target loop and the logger is
  %   configured to log this aggregate statistic.
  %
  %   Logging from mex functions can be done in at least two ways. In the
  %   first case, logging is performed manually within the mex function and
  %   the logged data is transferred into the reach of the Matlab logger
  %   via mexJoin(). In the second case, a mex extension of the logger does
  %   the logging automatically within the mex file and the logged data is
  %   transferred back within RunEpisodeMex. The latter would require a
  %   considerable amount of coding (mex versions of Logger and Iterative).
  
  % TODO Implement preallocation if necessary
  %
  %   Growing log matrices seem to have a negligible performance hit for
  %   small runs but might become a problem with longer runs. The
  %   straightforward solution would be to read the iteration counts from
  %   all iteratives and preallocate for that. However, you might want to
  %   avoid depending on fixed iteration counts. In that case, you might
  %   keep growing the logs until the topmost iterative has started its
  %   second iteration, at which point indices(1) = 2. Now the shape of the
  %   matrix is known except for the first dimension and eg exponential
  %   preallocation along the first dimension becomes an option.
  
  % TODO Consider making logs of row vector targets compact by transposing
  % row vectors before logging.
  
  % WARNING Summarized logging using the '=' interval has a hackish
  % solution for keeping the accumulator logs shallow, see
  % readAccumulator().
  
  
  %#ok<*MSNU>
  
  
  
  
  properties
    % User-configurable properties
    
    % Logging schema. Contains a struct array where each struct defines a
    % single logging rule. Fields:
    %
    %   .name           Name of the logging rule. This is used as the field
    %                   name when storing the logs. The name can contain
    %                   dots to produce nested fields. The name can be
    %                   omitted if logMode == 'none' (useful for progress
    %                   output rules).
    %   .trigger        Name of the triggering Iterative.
    %   .target         Name of the target object to be logged. If access
    %                   to multiple targets is needed, specify 'logger' as
    %                   the target to get a handle to the Logger object and
    %                   retrieve the target handles manually from the
    %                   Logger.targets property. The target can be omitted
    %                   if it is not needed in the rule command (useful for
    %                   progress output rules).
    %   .command        Command string for pulling the data from the
    %                   target. Unless the logMode is 'none', the following
    %                   string will be evaluated upon logging:
    %                     data = <command>
    %                   If logMode == 'none', then the command is evaluated
    %                   without any output arguments. During evaluation of
    %                   the command, the following variables are available:
    %                     'rule'      The rule struct.
    %                     'trigger'   A handle to the trigger object.
    %                     'target'    A handle to the target object.
    %                     'isBeforeFirst'   True before the first iteration.
    %                     'isAfterLast'     True after the last iteration.
    %                     'indices'   Vector of indices of the parent and
    %                                 current iteratives.
    %   .interval      Define whether logging should be performed before
    %                   the first iteration and after the last iteration.
    %                   The following strings are accepted:
    %                     '[]'   Log both
    %                     '()'   Log neither
    %                     '[)'   Log the former but not the latter
    %                     '(]'   Do not log the state before the first
    %                            iteration but do log the state after the
    %                            last iteration. (default)
    %                   You can add the character '=' to the end of the
    %                   mode string to log _only_ the specified endpoints.
    %                   For example, '(]=' will log only the state after
    %                   the last iteration and nothing else.
    %   .logMode        Either 'numeric', 'cell' or 'none'. See the main
    %                   documentation of the class. Default: 'numeric'
    schema = struct( 'name', {}, 'trigger', {}, 'target', {}, 'command', {}, 'interval', {}, 'logMode', {} );
    
    % Handles to the logging targets. Contains a struct where each field
    % defines a single logging target. The field name is the name of the
    % target and the value contained in the field is a handle to the
    % target.
    targets = struct();
    
  end
  
  
  properties
    % Properties set by Logger
    
    % the logs
    logs = struct( 'accumulator', struct() );
    
  end
  
  
  properties (Access=protected)
    
    % parent iteration name stack
    parentNames = {''};
    
    % parent iteration index stack
    parentIndices = {[]};
    
    % detected accumulator depths, used for keeping accumulators shallow
    accumulatorDepths = struct();
    
    % whether a endpoints-only rule is being processed (see readAccumulator)
    isProcessingJustEndpoints;
    
  end
  
  
  
  
  methods
    
    
    function this = Logger( varargin )
      % Construct a new Logger
      %
      %   this = Logger( 'schema', schema, 'targets', targets )
      %
      % For more details, see the documentation of the property fields
      % 'schema' and 'targets'.
      
      this.configure( varargin );
      
      % add self to targets (needed for accumulators)
      this.addTargets( 'logger', this );
      
    end
    
    function addRules( this, varargin )
      % Add rules to the schema.
      %
      %   addRules( this, <name/value pairs> ... )
      %
      % See the documentation of the 'schema' property for details.
      % Multiple rules can be defined at once using the struct array
      % construction syntax, i.e., by providing cell arrays for values to
      % be varied (see struct).
      
      % create struct
      rules = struct(varargin{:});
      
      % set defaults for missing fields
      if ~isfield(rules, 'name'); [rules.name] = deal([]); end
      if ~isfield(rules, 'interval'); [rules.interval] = deal('(]'); end
      if ~isfield(rules, 'logMode'); [rules.logMode] = deal('numeric'); end
      
      % add to schema
      this.schema = [this.schema, orderfields( rules, this.schema )];
      
    end
    
    function addTargets( this, varargin )
      % Add the given targets to the target list.
      %
      %   addTargets( this, <name>, <handle>, [<name2>, <handle2>, ...]
      %
      % Already existing targets with same names are overwritten.
      
      this.targets = catstruct( this.targets, struct(varargin{:}) );
      
    end
    
    function data = readAccumulator( this, name )
      
      % resolve our current iteration depth and store it (becomes stored repeatedly)
      depth = length( this.parentIndices{1} );
      if this.isProcessingJustEndpoints; depth = depth - 1; end   % hackish solution
      this.accumulatorDepths.(name) = depth;
      
      % read data
      try data = this.logs.accumulator.(name); catch; data = []; return; end                                  %#ok<CTCH>

      % make sure that the dimensions above our depth are singleton
      sz = size(data); assert( all( sz(1:depth) == 1 ), 'Internal error.' );

      % shift out the dimensions above current depth
      data = shiftdim( data, depth );

      % reset the accumulator
      this.logs.accumulator.(name) = [];

    end
    
    function finalize( this )
      % Discard all temporary data. The object should not be used for
      % logging after calling this.
      
      % remove the accumulator field
      this.logs = rmfield( this.logs, 'accumulator' );
      
      % TODO free preallocated memory
      
    end
    
    
    function logStepBegin( this, iterative )
      % Push the Iterative to the logger state stack. If first iteration,
      % then trigger logging rules that are associated with 'iterative'.
      %
      %   logStepBegin( this, iterative )
      %
      %   (Iterative) iterative
      %     The Iterative object that is requesting logging
      
      % add the iteration process to the state stack
      this.parentNames = { [this.parentNames{1} '.' iterative.name], this.parentNames };
      this.parentIndices = { [this.parentIndices{1}, iterative.iteration], this.parentIndices };
      
      % if the iteration process is starting, then log initial values
      if iterative.iteration == 1
        
        % process rules (replace index of the innermost Iterative with 0)
        this.processRules( this.parentNames{1}(2:end), [this.parentIndices{2}{1}, 0], iterative, true, false );
        
      end
      
    end
    
    function logStepEnd( this, iterative )
      % Trigger logging rules that are associated with 'iterative'. Pop the
      % Iterative from the logger state stack.
      %
      %   logStepEnd( this, iterative )
      %
      %   (Iterative) iterative
      %     The Iterative object that is requesting logging
      
      % process rules
      this.processRules( this.parentNames{1}(2:end), this.parentIndices{1}, iterative, false, ~iterative.isRunning() );
      
      % remove the iteration process from the state stack
      this.parentNames = this.parentNames{2};
      this.parentIndices = this.parentIndices{2};
      
    end
    
    
  end
  
  
  
  
  methods (Access=protected)
    
    
    function processRules( this, itName, indices, trigger, isBeforeFirst, isAfterLast )                      %#ok<INUSL>
      % Process all rules that are associated with 'itName'
      
      % loop through rules
      for rule=this.schema

        % consider skipping the rule
        if ~strcmp(rule.trigger, itName); continue; end
        if length(rule.interval) >= 3 && rule.interval(3) == '='
          % log only some endpoints
          if ~( (isBeforeFirst && rule.interval(1) == '[') || (isAfterLast && rule.interval(2) == ']') )
            continue;
          end
        else
          % log all but some endpoints
          if (isBeforeFirst && rule.interval(1) == '(') || (isAfterLast && rule.interval(2) == ')')
            continue;
          end
        end

        % process the rule

        % compute parent names, get a copy of the indices argument
        fieldname = [this.parentNames{1} '.' rule.name];
        currIndices = indices;

        % remove index positions of unlogged iterations (make the indexing compact)
        if length(rule.interval) >= 3 && rule.interval(3) == '='
          % log only some endpoints
          this.isProcessingJustEndpoints = true;   % used by readAccumulator(), which might be used in the rule command
          if isBeforeFirst || rule.interval(1) == '('; currIndices(end) = 1; else currIndices(end) = 2; end
        else
          % log all but some endpoints
          this.isProcessingJustEndpoints = false;
          if rule.interval(1) == '['; currIndices(end) = currIndices(end) + 1; end
        end

        % if accumulator rule, then keep shallow
        if strfind( rule.name, 'accumulator.' ) == 1

          fieldname = ['.' rule.name];
          try currIndices( 1:this.accumulatorDepths.(rule.name( length('accumulator.')+1:end )) ) = 1;
          catch err; if ~strcmp( err.identifier, 'MATLAB:nonExistentField' ); err.rethrow(); end; end

        end


        % pull data from target and store data
        target = this.targets.(rule.target);                                                               %#ok<NASGU>
        switch rule.logMode

          case 'numeric'   % pull data from target and store as matrix
            data = eval( rule.command );                                                                   %#ok<NASGU>
            colons = repmat( ':,', 1, ndims(data) ); colons(end) = [];
            eval([ 'this.logs' fieldname '(' sprintf('%d,', currIndices) colons ') = data;' ]);

          case 'cell'   % pull data from target and store as cell array
            data = eval( rule.command );                                                                   %#ok<NASGU>
            eval([ 'this.logs' fieldname sprintf('{%d}', currIndices) ' = data;' ]);

          case 'none'   % just execute command
            eval( rule.command );

          otherwise
            error( 'Unknown logging mode: ''%s''', rule.logMode );
        end

      end

    end


  end
  
end
