classdef Experiment < Configurable & Copyable & handle
  %EXPERIMENT Perform repeated agent training with different learning parameters.
  %
  %   Perform systematic agent training runs with different parameters. The
  %   training runs with each parameter set is performed using the Trainer
  %   class. Parallelization is supported via the Matlab Parallel Computing
  %   Toolbox.
  %
  %   The experiment is configured by filling in the public properties
  %   shown below. The experiment is started with the Experiment.run()
  %   method. Results are available in the second set of public properties
  %   shown below.
  %
  %   Some results processing and visualization can be performed using the
  %   Experiment.getResults(), Experiment.plotResults() and
  %   Experiment.plotResultsNontemporal() methods.
  %
  %   The bulk of the needed memory for the returned trainer objects is
  %   consumed by the logs. For a small memory footprint, use a low logging
  %   level (see Trainer).
  %
  %   See also Trainer, GradientMapper
  
  % TODO Rename paramRanges to paramSweeps, or similar.
  
  %#ok<*PROP>
  %#ok<*AGROW>
  
  
  properties
    % These fields are to be filled by user before calling run()
    
    
    % Experiment definition
    
    % Random seeds will be picked sequentially starting from this seed.
    %   (int)
    firstSeed = 1;
    
    % Number of repetitions for each distinct parameter set.
    %   (int)
    repeats = 1;
    
    % Callback function that is to be used for performing a single training
    % session. The function should accept a parameter struct as an input
    % and return a Trainer object as a result. The parameter struct is
    % merged from the fields this.params and this.paramRanges, and the
    % field 'seed' is added to it.
    %   (Trainer (trainFunc)(params))
    trainFunc;
    
    % Default values for all learning parameters. The required parameters
    % are defined by the inheriting class that implements the train()
    % method.
    %   (struct)
    params = struct();
    
    % Learning parameters to be varied. Ranges are provided as struct
    % fields whose names correspond to parameter names. The fields must
    % contain one-dimensional cell arrays, with each cell holding a value
    % for the parameter.
    %   (struct)
    paramRanges = struct();
    
    % (optional) Labels for each parameter value in paramRanges. Labels are
    % provided as struct fields whose names correspond to parameter names.
    % The fields must contain one-dimensional cell arrays, with each cell
    % holding a string label for the corresponding parameter value in
    % paramRanges. This is used only in getResults() and plotResults(). If
    % omitted, then num2str() is performed on the parameter value.
    %   (struct)
    paramValueLabels = struct();

    
    % Parallelization configuration
    
    % If set, then the experiment is run using the parallel computing
    % toolbox with the specified configuration. This setting can be
    % overrided in the run() call.
    %   (passed to the parallel computing toolbox as a configuration)
    parallelConfiguration = Configuration.Experiment.parallelConfiguration;
    
    % Path prefix to the software root directory for the parallel job
    % workers, if different from the path on the client machine. This
    % setting can be overrided in the run() call. Default, if []: current
    % path prefix on the client machine
    %   (string)
    parallelPathPrefix = Configuration.Experiment.parallelPathPrefix;
    
    % Maximum number of task groups. If there are more tasks than
    % parallelMaxTaskGroups, then several tasks will be grouped into a
    % single parallel computing toolbox task. This is useful for a large
    % number of short tasks with which the overhead of full parallelization
    % would outweigh the benefits. This setting can be overrided in the
    % run() call.
    %   (int)
    parallelMaxTaskGroups = Configuration.Experiment.parallelMaxTaskGroups;
    
  end
  
  
  properties
    % These fields are filled by run()
    
    % Experiment results. The results field is a multidimensional array
    % with each dimension corresponding to one parameter from paramRanges.
    % Repeats run along an additional last dimension. The field
    % 'paramNames' lists the parameter names for the dimensions.
    %   (length(fieldnames(this.paramRanges))+1 -dimensional struct array)
    %
    % Fields:
    %   (struct) params
    %     Parameters that were used for this element
    %   (Trainer) trainer
    %     The Trainer object
    results;
    
    % Names of the learning parameters that were varied. These are equal to
    % the field names in this.paramRanges, except for an additional last
    % element 'repeat'.
    %   (length(fieldnames(this.paramRanges))+1 -element cell array of
    %   strings)
    paramNames;
    
    % Pre-extracted data from the results. The first dimensions correspond
    % to the parameters listed in this.paramNames. The iterations or
    % episodes run along the additional last dimension. See also:
    % getResults()
    %   (length(this.paramNames)+1 -dimensional double array)
    returnsTrain; returnsTrainTest; returnsTest; condsTrain;
    
    % In case of errors during parallel execution, the parallel job object
    % will be stored to this property. Otherwise it will be left empty.
    errorJob = [];
    
  end
  
  
  
  
  methods (Static)
    
    % Cancel all jobs that are running on the scheduler used by the
    % configuration that is given in the parallelConfiguration argument.
    function CancelJobs( parallelConfiguration )
      
      scheduler = parcluster( parallelConfiguration );
      if ~isempty(scheduler.Jobs); scheduler.Jobs.cancel(); end
      
    end
    
  end
  
  
  
  
  % public methods begin
  
  
  methods
    
    function run( this, varargin )
      % Run the experiment.
      %
      %   'parallelConfiguration', config
      %     This can be used to override the configuration in the
      %     parallelConfiguration property.
      %
      %   'parallelPathPrefix', (string) prefix
      %     Path prefix to the software root directory for the parallel job
      %     workers, if different from the path on the client machine.
      %     Default, if [] or omitted: current path prefix on the client
      %     machine
      %
      %   'parallelMaxTaskGroups', (int) maxTaskGroups
      %     This can be used to override the configuration in the
      %     parallelMaxTaskGroups property.
      
      % parse args
      args = inputParser;
      args.addParamValue( 'parallelConfiguration', this.parallelConfiguration );
      args.addParamValue( 'parallelPathPrefix', [], @(x) (isempty(x) || ischar(x)) );
      args.addParamValue( 'parallelMaxTaskGroups', this.parallelMaxTaskGroups, @(x) (isscalar(x) && isnumeric(x)) );
      args.parse( varargin{:} );
      
      % assign args
      parallelConfiguration = args.Results.parallelConfiguration;
      if ~isempty(args.Results.parallelPathPrefix)   % needed for accepting []. TODO: is there need for passing []?
        parallelPathPrefix = args.Results.parallelPathPrefix;
      else
        parallelPathPrefix = this.parallelPathPrefix;
      end
      parallelMaxTaskGroups = args.Results.parallelMaxTaskGroups;
      
      
      % init seed and paramNames
      nextSeed = this.firstSeed;
      this.paramNames = [ fieldnames(this.paramRanges) ; {'repeat'} ];
      
      % compute the dimensions of the results struct
      dims = zeros(1, length(this.paramNames));
      for i=1:length(this.paramNames)-1
        dims(i) = length(this.paramRanges.(this.paramNames{i}));
      end
      dims(end) = this.repeats;
      
      % generate tasks: scan through all combinations of ranged params
      this.results = repmat( struct(), [dims 1] );   % have to help Matlab in creating 1-dimensional arrays
      for i=1:numel(this.results)
        
        % convert the flat index into an index vector
        [inds{1:length(dims)}] = ind2sub( dims, i );

        % compute params
        params = this.params;
        for j=1:length(inds)-1
          fieldname = this.paramNames{j};
          params.(fieldname) = this.paramRanges.(fieldname){ inds{j} };
        end
        
        % add/overwrite seed
        params.seed = nextSeed; nextSeed = nextSeed + 1;

        % store data
        this.results(i).params = params;
        
      end
      
      % run tasks
      if ~isempty(parallelConfiguration)
        
        % Run using the parallel computing toolbox
        this.runParallel( parallelConfiguration, parallelPathPrefix, parallelMaxTaskGroups );
        
      else
        
        % Run sequentially
        
        assert( isa( this.trainFunc, 'function_handle' ), 'Experiment.trainFunc must be a function handle!' );
        
        % loop through tasks
        nTasks = numel(this.results);
        for i=1:nTasks
          fprintf('\n\n*** Experiment: Running task %d of %d\n\n', i, nTasks );
          this.results(i).trainer = this.trainFunc( this.results(i).params );
        end
        
      end
      
      fprintf('\n\nExperiment: All tasks finished. Processing results..');
      
      
      % extract statistics
      
      % loop through results
      for i=numel(this.results):-1:1
        
        % convert the flat index into an index vector
        [inds{1:length(dims)}] = ind2sub( dims, i );
        
        % extract returns and conds
        this.returnsTrain(inds{:},:) = this.results(i).trainer.results.returnsTrainIterations;
        this.condsTrain(inds{:},:) = this.results(i).trainer.results.condsTrainIterations;
        this.returnsTrainTest(inds{:},:) = this.results(i).trainer.results.returnsTrainTestIterations;
        this.returnsTest(inds{:},:) = this.results(i).trainer.results.returnsTestEpisodes;
        
      end
      
      fprintf(' done\n');
      
    end
    
    
    function [data, labels, dataMg, agentLogs] = getResults( this, fieldname, inds )
      % Get processed summary data.
      %
      %   (string) fieldname
      %     Pick one of the public result fields from the Experiment class
      %     ('returnsTrain', 'condsTrain', 'returnsTrainTest',
      %     'returnsTest'). Default, if [] or omitted: 'returnsTrain'
      %
      %   (cell array) inds
      %     Cell array with length(this.paramNames) elements. Each cell can
      %     contain either a number, in which case only that element from the
      %     corresponding dimension is selected, a vector, in which case the
      %     indicated elements from the corresponding dimension are selected,
      %     or it can be one of the characters: ':', 'm', 's', 'v', which
      %     stand for all, mean, std, and var, respectively. Use the
      %     properties this.paramNames and this.paramRanges as reference.
      %     Default, if [] or omitted: {':', 'm'} (works only in basic cases)
      %
      %   (multidimensional double array) data
      %     Contains the data from the field 'fieldname' after being
      %     processed according to the operators in 'inds'. Singleton
      %     dimensions have been removed.
      %
      %   (struct) labels
      %     Summary labels that can be used for plotting. Fields:
      %       (string) title
      %         Summary string.
      %       (cell array of cell arrays of strings) legends
      %         legends{n}{m} contains the name of the m:th parameter value
      %         in the range of the n:th ':' operator in 'inds'. This field
      %         will be {} if no ':' operators were used.
      %
      %   (multidimensional double array) dataMg
      %     Equal to 'data', except for an additional flattened last
      %     dimension that contains the elements from all dimensions that
      %     were averaged in 'data'. This is primarily for internal use in
      %     plotResults().
      %
      %   (struct) agentLogs
      %     Agent logs after being processed according to the operators in
      %     'inds'. Using of statistics operators ('m', 's', 'v') is not
      %     supported and will result in an empty agentLogs.
      
      % set defaults
      if ~exist( 'fieldname', 'var' ) || isempty(fieldname); fieldname = 'returnsTrain'; end
      if ~exist( 'inds', 'var' ) || isempty(inds); inds = {':', 'm'}; end
      
      % check conditions
      assert( length(inds) == length(this.paramNames), ...
        'The ''inds'' argument must have an equal length with the ''this.paramNames'' field.' );
      
      % pick data
      data = this.(fieldname);
      if nargout >= 4; agentLogs = getAgentLogs( this ); else agentLogs = []; end
      
      % init title label and legends
      labels.title = [fieldname ': ']; labels.legends = {}; labels.paramNames = {}; labels.paramValueNames = {};
      
      % prepare for grayscale-averaging (mg, or mean-gray)
      indsMg = inds; dimsMg = [];
      
      % scan through dimensions
      nFullDims = 0;
      for i=1:length(inds)
        
        % extract param name
        paramName = this.paramNames{i};
        
        % process dimension
        if isnumeric(inds{i}) && isscalar(inds{i})
          
          % a single value is being picked
          
          % just get a name for that value
          paramValueName = computeParamValueName( this, paramName, inds{i} );
          
        elseif ( isnumeric(inds{i}) && isvector(inds{i}) ) || isequal(inds{i}, ':')
          
          % some range is being picked
              
          nFullDims = nFullDims + 1;
          if isequal(inds{i}, ':')
            paramValueName = '(:)';
            range = 1:size(data,i);
          else
            paramValueName = '(range)';
            range = inds{i};
          end
          labels.paramNames{nFullDims} = paramName;
          for j=1:length(range)
            labels.paramValueNames{nFullDims}{j} = computeParamValueName( this, paramName, range(j) );
            labels.legends{nFullDims}{j} = [ paramName '=' labels.paramValueNames{nFullDims}{j} ];
          end
        
        elseif ischar(inds{i}) && ~strcmp( inds{i}, ':' )
          
          % some statistic is being picked
          
          % perform the operation and select a name
          switch inds{i}
            case {'m', 'M'}
              data = mean( data, i ); inds{i} = 1; indsMg{i} = ':'; dimsMg(end+1) = i; paramValueName = '(mean)';
            case {'s', 'S'}
              data = std( data, 0, i ); inds{i} = 1; indsMg{i} = 1; paramValueName = '(std)';
            case {'v', 'V'}
              data = var( data, 0, i ); inds{i} = 1; indsMg{i} = 1; paramValueName = '(var)';
            otherwise
              assert(false, 'Unrecognized dimension operator at position %d.', i);
          end
          
          % agentLogs processing is not supported; clear it
          agentLogs = [];
          
        else
          
          assert(false, 'Unrecognized dimension operator at position %d.', i);
          
        end
        
        % add the operation name to the title label
        labels.title = [labels.title paramName '=' paramValueName ', '];
        
      end
      
      % trim title
      labels.title(end-1:end) = [];
      
      % pick subset and squeeze
      data = squeeze( data(inds{:},:) ); if isvector(data); data = data(:); end
      if ~isempty(agentLogs)
        agentLogs = squeeze( agentLogs(inds{:}) ); if isvector(agentLogs); agentLogs = agentLogs(:); end
      end
      
      % get data for grayscale-averaging and permute the mg dimensions to
      % the beginning
      dataMg = this.(fieldname);
      i=1:ndims(dataMg); i(dimsMg) = []; i = [dimsMg i];
      dataMg = permute( dataMg(indsMg{:},:), i );
      
      % flatten the mg dimensions that are at the beginning
      dataMgSize = size(dataMg);
      dataMgSize = [ prod( dataMgSize(1:length(dimsMg)) ) dataMgSize(length(dimsMg)+1:end) ];
      dataMg = reshape( dataMg, dataMgSize );
      
      % shift mg dimensions back to the end and squeeze
      dataMg = squeeze(shiftdim(dataMg,1)); if isvector(dataMg); dataMg = dataMg(:); end
      
    end
      
      
    function logs = getAgentLogs( this )

      % collect log structs
      for i=1:numel(this.results)
        logs(i) = this.results(i).trainer.logger.logs;
      end

      % reshape
      logs = reshape( logs, size(this.results) );

    end
    
    
    function [data, labels] = plotResults( this, varargin )
      % Plot results.
      %
      %   [data, labels] = plotResults( this, ['field', fn], ['inds', inds],
      %       ['error', err, ['errormode', em], ['errorestimation', ee]] )
      %
      % See getResults() for details on the arguments
      % 'field' (fieldname), 'inds', 'data', and 'labels'.
      %
      %   ['error', (string) err]
      %     The argument 'err' is one of:
      %       'none'           No error plots.
      %       'bars'           Plot error bars.
      %       'lines'          Plot error lines.
      %       'distribution'   Illustrate the distributions using
      %                        multiple layers of faint lines that are
      %                        averages of fewer results. The illustration
      %                        process might not be deterministic.
      %
      %   ['errormode', (string) em]
      %     If error plotting is on, then 'mode' can be either 'std' for
      %     plotting the standard deviation of the mean, or 'ci' for plotting
      %     the 95% confidence interval of the mean.
      %
      %   ['errorestimation', (string) est]
      %     The argument 'est' can be either 'statistics, 'bootstrap', or
      %     'jackknife'.
      
      % parse args
      args = inputParser;
      args.addParamValue( 'field', [], @ischar );
      args.addParamValue( 'inds', [], @iscell );
      args.addParamValue( 'error', 'none', @ischar );
      args.addParamValue( 'errormode', 'std', @ischar );
      args.addParamValue( 'errorestimation', 'statistics', @ischar );
      args.parse( varargin{:} );
      p = args.Results;
      
      % obtain data
      [data, labels, dataMg] = getResults( this, p.field, p.inds );
      
      % handle 1d case: assume that the only non-singleton dimension (which
      % would be dimension 1) corresponds to iterations. add a singleton
      % dimension to the beginning to represent the single result to be
      % plotted
      if isvector(data); data = shiftdim(data,-1); dataMg = shiftdim(dataMg,-1); end
      
      % >3d is not allowed
      assert( ~(ndims(data) > 3), 'Range operators can be used for two dimensions at most when plotting.' );
      
      
      % handle 3d case: flatten first two dimensions (assume that the last
      % dimension corresponds to iterations)
      if ndims(data) == 3
        
        % flatten legends
        for i=1:size(data,1)
          for j=1:size(data,2)
            legends{ (j-1) * size(data,1) + i } = [labels.legends{1}{i} ', ' labels.legends{2}{j}];
          end
        end
        labels.legends = {legends};
        
        % flatten data
        data = reshape( data, size(data,1)*size(data,2), size(data,3) );
        dataMg = reshape( dataMg, size(dataMg,1)*size(dataMg,2), size(dataMg,3), size(dataMg,4) );
        
      end
      
      
      % set line styles
      %colors = get(gca,'ColorOrder');
      colors = repmat( [1, 0.75, 1], size(data, 1), 1) .* jet( size(data, 1) );
      lineWidths = repmat( 1.0, 1, size(data, 1) );
      lineStyles = repmat( {'-', '--', '-.'}, 1, ceil(size(data, 1)/3) );
      errorLightness = 4;

      % clear the axis, hold on
      cla; hold on;

      switch p.error
        
        case 'none'
          
          % plot 'data'
          handles = [];
          for i=1:size(data, 1)
            handles(end+1) = plot( data(i,:), ...
              'LineWidth', lineWidths(i), 'LineStyle', lineStyles{i}, 'Color', colors(i,:) );
          end
          
          % annotate using 'labels'
          title( labels.title, 'Interpreter', 'none' );
          if ~isempty( labels.legends ); legend( handles, labels.legends{1}, 'Interpreter', 'none' ); end
          
        case {'bars', 'lines'}
          
          % plot 'data' with error bars and annotate using 'labels'
          
          % compute mean and the standard deviation of the mean
          [dataMean, dataStd] = computeDataStatistics( this, dataMg, 3, p.errorestimation, p.errormode );
          
          % plot 'data' with an error plot
          handles = [];
          for i=1:size(dataMean, 1)
            switch p.error
              case 'bars'
                handles(end+1) = errorbar( dataMean(i,:), dataStd(i,:), 'LineWidth', lineWidths(i), ...
                  'LineStyle', lineStyles{i}, 'Color', colors(i,:) );
              case 'lines'
                handles(end+1) = plot( data(i,:), 'LineWidth', lineWidths(i), ...
                  'LineStyle', lineStyles{i}, 'Color', colors(i,:) );
                plot( data(i,:) - dataStd(i,:), 'LineWidth', lineWidths(i), 'LineStyle', lineStyles{i}, ...
                  'Color', 1 - (1 - colors(i,:)) / errorLightness );
                plot( data(i,:) + dataStd(i,:), 'LineWidth', lineWidths(i), 'LineStyle', lineStyles{i}, ...
                  'Color', 1 - (1 - colors(i,:)) / errorLightness );
            end
          end
          
          % annotate using 'labels'
          title( labels.title, 'Interpreter', 'none' );
          if ~isempty( labels.legends ); legend( handles, labels.legends{1}, 'Interpreter', 'none' ); end
          
        case 'distribution'
          
          % configure distribution layers
          nFaintLines = [10 5];
          lightness = [0.9 0.75];
          widthMultiplier = 1 * [1 1];
          lineWidths = 1 * lineWidths;
          %lightness = [0.9 0.5];
          %widthMultiplier = 0.5 * [1 1];
          %lineWidths = 2 * lineWidths;

          % randomize mg data order
          dataMg = dataMg(:,:,randperm(size(dataMg,3)));

          % plot faint lines; loop through main lines
          for i=1:size(data, 1)

            % loop through faintness levels
            for level=1:length(nFaintLines)
              nLines = nFaintLines(level);

              % use only a multiple of 'nLines'
              averagingN = floor(size(dataMg,3)/nLines);

              % loop through individual lines
              for j=1:nLines
                lineData = squeeze( mean( dataMg( i, :, (j-1)*averagingN+1:j*averagingN ), 3 ) );
                plot( lineData, ...
                  'LineWidth', widthMultiplier(level) * lineWidths(i), ...
                  'LineStyle', lineStyles{i}, ...
                  'Color', lightness(level) + (1 - lightness(level)) * colors(i,:) );
              end

            end

          end
          
          % plot main lines
          handles = [];
          for i=1:size(data, 1)
            handles(end+1) = plot( data(i,:), ...
              'LineWidth', lineWidths(i), 'LineStyle', lineStyles{i}, 'Color', colors(i,:) );
          end
          
          % annotate using 'labels'
          title( labels.title, 'Interpreter', 'none' );
          if ~isempty( labels.legends ); legend( handles, labels.legends{1}, 'Interpreter', 'none' ); end
          
        otherwise
          
          hold off;
          error( 'Unrecognized mode ''%s''.', mode );
          
      end
      
      % hold off
      hold off;

    end
    
    
    function [data, labels] = plotResultsNontemporal( this, varargin )
      % Plot non-temporal results, i.e., treat the iterations (the last
      % dimension) as repeated independent sampling.
      %
      %   [data, labels] = plotResultsNontemporal( this, ...,
      %       ['mode', m], ['error', err, ...] )
      %
      %   ['mode', (string) m]
      %     The argument 'm' is one of:
      %       'bars'           Bar plot.
      %       'map'            Map plot using image().
      %
      %   ['error', (string) err]
      %     The argument 'err' is one of:
      %       'none'           No error plots.
      %       'bars'           Plot error bars.
      %
      % See getResults() and plotResults() for details on other arguments.
      
      % parse args
      args = inputParser;
      args.addParamValue( 'field', [], @ischar );
      args.addParamValue( 'inds', [], @iscell );
      args.addParamValue( 'mode', 'bars', @ischar );
      args.addParamValue( 'error', 'none', @ischar );
      args.addParamValue( 'errormode', 'std', @ischar );
      args.addParamValue( 'errorestimation', 'statistics', @ischar );
      args.parse( varargin{:} );
      p = args.Results;
      
      % obtain data
      [data, labels, dataMg] = getResults( this, p.field, p.inds );
      
      % handle 1d case: assume that the only non-singleton dimension (which
      % would be dimension 1) corresponds to iterations. add a singleton
      % dimension to the beginning to represent the single result to be
      % plotted
      if isvector(data); data = shiftdim(data,-1); dataMg = shiftdim(dataMg,-1); end
      
      % data should have 2 or 3 dimensions, from which the last dimension
      % corresponds to test episodes (repeats). dataMg should have one more
      % dimension.
      assert( ~(ndims(data) > 3), 'Range operators can be used for two dimensions at most when plotting.' );

      
      % handle 3d case: if mode == bars, then flatten first two dimensions (assume that the last
      % dimension corresponds to repeats)
      if strcmp(p.mode, 'bars') && ndims(data) == 3
        
        % flatten legends
        for i=1:size(data,1)
          for j=1:size(data,2)
            legends{ (j-1) * size(data,1) + i } = [labels.legends{1}{i} ', ' labels.legends{2}{j}];
          end
        end
        labels.legends = {legends};
        
        % flatten data
        data = reshape( data, size(data,1)*size(data,2), size(data,3) );
        dataMg = reshape( dataMg, size(dataMg,1)*size(dataMg,2), size(dataMg,3), size(dataMg,4) );
        
      end
      
      
      % concatenate test episodes to the additional dimension in dataMg
      i = size(dataMg);
      if ndims(dataMg) == ndims(data); i(end+1) = 1; end   % degenerate mg dimension? (no 'm' operators in 'inds')
      i = [ i(1:end-2), i(end-1) * i(end) ];
      dataMg = reshape( dataMg, i );
      
      
      % (re)compute mean and the standard deviation of the mean
      [data, dataStd] = computeDataStatistics( this, dataMg, ndims(dataMg), p.errorestimation, p.errormode );
      
      
      % clear the axis, no hold
      cla; hold off;

      % plot
      switch p.mode
        
        case 'bars'
          
          % set line styles
          colors = repmat( [1, 0.75, 1], size(data, 1), 1) .* jet( size(data, 1) );

          handles = [];
          for i=1:size(data, 1)
            handles(end+1) = bar( i, data(i), 'FaceColor', colors(i,:) );
            if strcmp(p.error, 'bars')
              errorbar( i, data(i), dataStd(i), 'Color', 'black', 'LineStyle', 'none' );
            end
          end
          
          if ~isempty( labels.legends ); legend( handles, labels.legends{1}, 'Interpreter', 'none' ); end
          
        case {'map', 'mesh', 'contour'}
          
          switch p.mode
            case 'map'
              imagesc( data' ); axis xy;
              colorbar;
            case 'mesh'
              surf( data' );
            case 'contour'
              contourf( data' );
          end
          set( gca, 'XTick', 1:size(data,1) );
          set( gca, 'YTick', 1:size(data,2) );
          if size(data,2) == 1; set( gca, 'YTick', [] ); end
          
          xlabel( labels.paramNames{1} );
          set( gca, 'XTickLabel', labels.paramValueNames{1} );
          if length(labels.paramNames) > 1
            ylabel( labels.paramNames{2} );
            set( gca, 'YTickLabel', labels.paramValueNames{2} );
          end
          
        otherwise
          error( 'Unrecognized mode ''%s''.', p.mode );
          
      end
      
      % add title
      title( labels.title, 'Interpreter', 'none' );
      
    end
    
    
  end
  
  
  
  
  % Protected and private methods begin  
  
  
  
  
  methods (Access=protected)
    
    function trainers = runTaskGroup( this, taskGroup )
      % Run a single task group and return the trainers as a Trainer array.
      
      for i=1:length(taskGroup)
        trainers(i) = this.trainFunc( taskGroup(i).params );
      end
      
    end
    
  end
  
  
  
  
  methods (Access=private)
    
    
    function runParallel( this, parallelConfiguration, parallelPathPrefix, parallelMaxTaskGroups )

      % check cluster size
      scheduler = parcluster( parallelConfiguration );
      nWorkers = scheduler.NumWorkers;

      % create task groups with permutation
      nTasks = numel(this.results);
      parallelTaskGroupSize = max( 1, ceil( nTasks / parallelMaxTaskGroups ) );
      nTaskGroups = ceil( nTasks / parallelTaskGroupSize );
      taskPermutation = randperm(nTasks);
      for i=1:nTaskGroups
        range = (i-1)*parallelTaskGroupSize+1 : min(i*parallelTaskGroupSize, nTasks);
        taskGroups{i} = this.results(taskPermutation(range));
      end

      fprintf( 'Experiment: Running %d tasks in %d groups using parallel computing toolbox with %d workers.\n', ...
        nTasks, nTaskGroups, nWorkers );
      fprintf( '  The job can be cancelled with the following command:\n    Experiment.CancelJobs(''%s'')\n\n', ...
        parallelConfiguration );

      % send the job
      job = createJob( parcluster(parallelConfiguration), ...
        'AdditionalPaths', setpaths( 'pathPrefix', parallelPathPrefix, 'doAddpath', false ) );
      for i=1:length(taskGroups)
        createTask( job, @runTaskGroup, 1, { this, taskGroups{i} } );
      end
      job.submit();

      % wait for completion while printing progress information
      minDelay = 4; maxDelay = 1024; delay = minDelay;
      runningTasks = NaN; finishedTasks = NaN; errors = false; errorMsg = '';
      while true

        % count running and finished tasks; check for errors
        tasks = job.Tasks; runningTasks_ = 0; finishedTasks_ = 0;
        for i=1:length(tasks)
          if ~isempty( tasks(i).ErrorIdentifier ); errors = true; errorMsg = tasks(i).ErrorMessage; tasks(i), end
          state = tasks(i).State;
          if strcmp(state, 'running'); runningTasks_ = runningTasks_ + 1; end
          if strcmp(state, 'finished'); finishedTasks_ = finishedTasks_ + 1; end
        end

        % break if errors
        if errors; break; end

        % If the counts have changed, then
        % update counters, decrease the delay, print, and check if finished. Otherwise increase the
        % delay.
        if runningTasks_ ~= runningTasks || finishedTasks_ ~= finishedTasks
          runningTasks = runningTasks_; finishedTasks = finishedTasks_;
          delay = max( minDelay, delay / 2 );
          fprintf('  Finished task groups: %d/%d   (running task groups: %d)\n', ...
            finishedTasks, nTaskGroups, runningTasks );
          if finishedTasks == nTaskGroups; break; end
        else
          delay = min( maxDelay, 2 * delay );
        end

        % delay
        if runningTasks < min( nWorkers, nTaskGroups - finishedTasks )
          pause(minDelay);
          delay = max( minDelay, delay / 2 );
        else
          pause(delay);
        end

      end

      % check for errors
      if errors
        job.cancel;
        this.errorJob = job;
        global ERROR_EXPERIMENT;
        ERROR_EXPERIMENT = this;
        error( 'Experiment:parallelErrors', ...
          [ 'Parallel execution failed due to errors. The job object has been stored to the ' ...
            'Experiment.errorJob property.\nThe Experiment object has been stored to the global variable ' ...
            'ERROR_EXPERIMENT.\n' ...
            'Error message for the first encountered error: %s' ], errorMsg );
      end

      % retrieve results and unpermute
      trainerGroups = fetchOutputs( job );
      trainers = num2cell( [trainerGroups{:}] );
      [this.results(taskPermutation).trainer] = trainers{:};

    end
    
    
    function name = computeParamValueName( this, paramName, ind )

      if isfield( this.paramValueLabels, paramName )
        % use the provided name
        name = this.paramValueLabels.(paramName){ind};
      elseif isfield( this.paramRanges, paramName )
        % try to use num2str(value)
        try
          name = num2str( this.paramRanges.(paramName){ind} );
        catch                                                                                                 %#ok<CTCH>
          % use num2str(ind)
          name = num2str(ind);
        end
      else
        % use num2str(ind)
        name = num2str(ind);
      end

    end
    
    
    function [dataMean, dataStd] = computeDataStatistics( this, dataMg, dim, mode, errormode )
      
      % select std or 95% ci
      if strcmp(errormode, 'ci'); stdmult = 2; else stdmult = 1; end

      dataMean = mean(dataMg,dim);
      
      perm = [dim, 1:(dim-1)];
      switch mode
        case 'statistics'
          dataStd = stdmult * std(dataMg,0,dim) / sqrt(size(dataMg,dim));
        case 'bootstrap'
          bootsample = reshape( bootstrp( 1000, @mean, permute(dataMg,perm), 1 ), [1000 size(dataMean)] );
          dataStd = shiftdim( stdmult * std( bootsample, 0, 1 ), 1 );
        case 'jackknife'
          bootsample = reshape( jackknife( @mean, permute(dataMg,perm), 1 ) .* sqrt(size(dataMg,dim)), ...
                                size(permute(dataMg,perm)) );
          dataStd = shiftdim( stdmult * std( bootsample, 0, 1 ), 1 );
      end
      
    end
    
    
  end
  
  
end
