classdef GradientMapper < Experiment
  %GRADIENTMAPPER Map performance in the direction of given gradients
  %
  %   Map performance in the direction of gradient estimates obtained from
  %   the given agent logs. To use the mapper: create the object, fill the
  %   property fields as needed, and call run().
  %
  %   Fields that must be set before calling run():
  %     GradientMapper.agentLogs
  %     GradientMapper.alpha
  %     Experiment.trainFunc
  %
  %   Other fields that you might consider setting:
  %     Experiment.params.episodesIt
  %
  %   It is assumed that the function assigned to Experiment.trainFunc
  %   understands the following parameters: theta0, iterations.
  
  
  properties
    
    % Agent logs for which the mapping should be performed. The logs should
    % contain one entry per iteration (not checked!).
    % Experiment.getResults() and Experiment.getAgentLogs() return the logs
    % in the correct form. All logs should have the same number of
    % iterations (not checked!).
    %   (n-d struct array) agentLogs
    agentLogs;
    
    % Step-size values to be used for mapping
    %   (double array) alpha
    alpha;
    
  end
  
  properties (Access=protected)
    
    % Original shape of this.paramRanges.theta0 and results
    resultsShape;
    
  end
  
  
  methods
    
    function this = GradientMapper()
      % Constructor.
      
      % set defaults (assume that the trainFunc supports these basic fields)
      this.params.iterations = 1;
      
    end
    
    
    function this = run( this, varargin )
      % Run the mapper.
      
      % init
      this = init( this );
      
      % run
      this = run@Experiment( this, varargin{:} );
      
      % reshape results
      this.results = reshape( this.results, this.resultsShape );
      for fn={'returnsTrain', 'condsTrain'}
        if ~isempty( this.(fn{1}) )
          this.(fn{1}) = reshape( this.(fn{1}), this.resultsShape );
        end
      end
      
      % write this.paramNames
      this.paramNames = {};
      for i=1:length(this.resultsShape)-2
        this.paramNames{i} = ['dim' num2str(i)];
      end
      this.paramNames(end+1:end+2) = {'iteration', 'alpha'};
      
    end
    
    
    function plotResults( this, field, inds, clim )
      % Plot results.
      %
      %   plotResults( this, field, inds, clim )
      %
      %   (string) fieldname
      %     Pick one of the public result fields from the Experiment class
      %     ('returnsTrain', 'returnsTest', 'condsTrain'). Default, if [] or
      %     omitted: 'returnsTrain'
      %
      %   (cell array) inds
      %     Cell array with ndims(this.agentLogs) elements. Each cell must
      %     contain a number. Advanced processing (as in
      %     Experiment.getResults) is not supported.
      %
      %   (2-element double vector) clim
      %     Optional clim argument to be passed to imagesc. Omit or set to []
      %     to use automatic scaling.
      
      % set defaults
      if ~exist('field', 'var') || isempty(field); field = 'returnsTrain'; end
      if ~exist('inds', 'var') || isempty(inds)
        if ndims(this.(field)) == 3 && size(this.(field),1) == 1; inds = {1}; else inds = {}; end
      end
      if ~exist('clim', 'var') || isempty(clim); clim = {}; else clim = {clim}; end
      
      % pick results of the indicated log element
      assert( length(inds) + 2 == ndims(this.(field)), ...
        ['The length of the ''inds'' argument must match the dimensionality of the ''this.agentLogs'' field.'] );
      returns = shiftdim( this.(field)(inds{:},:,:), length(inds) );
      
      % plot
      cla;
      imagesc( returns', clim{:} ); axis xy; h=colorbar;
      xlabel( 'iteration' ); ylabel( 'step-size' ); ylabel( h, 'return' );
      set( gca, 'YTick', 1:length(this.alpha) );
      set( gca, 'YTickLabel', this.alpha );
      
    end
    
    
    function plotGradients( this, inds )
      % Plot gradient directions and magnitudes.
      %
      %   plotGradients( this, inds )
      %
      %   (cell array) inds
      %     Cell array with ndims(this.agentLogs) elements. Each cell must
      %     contain a number. Advanced processing (as in
      %     Experiment.getResults) is not supported.
      
      % set defaults
      if ~exist('inds', 'var') || isempty(inds); inds = {}; end
      
      % pick the indicated log element
      assert( ...
        (length(inds) < 2 && isvector(this.agentLogs)) || ...
        (length(inds) == ndims(this.agentLogs)), ...
        ['The length of the ''inds'' argument must match the dimensionality of the ''this.agentLogs'' field.'] );
      logs = this.agentLogs( inds{:} );
      assert( isscalar(logs), 'The ''inds'' argument must be used to select a single log entry.' );
      
      % compute gradient magnitudes and the angles between all gradients (produce a symmetric matrix)
      ngradients = size(logs.Q, 1);
      magnitudes = nan(1, ngradients);
      angles = nan(ngradients);
      for i=1:ngradients
        magnitudes(i) = norm(logs.Q(i,:));
        for j=1:ngradients
          angles(i,j) = sum( logs.Q(i,:) .* logs.Q(j,:) ) / ( norm(logs.Q(i,:)) * norm(logs.Q(j,:)) );
        end
      end
      angles = min( max( angles, -1 ), 1 );
      
      % plot
      clf;
      subplot(2,1,1);
      plot( 0:ngradients-1, magnitudes ); x=axis; x(1:2) = [0 ngradients-1]; axis(x); colorbar;
      xlabel('iteration'); ylabel('gradient magnitude');
      subplot(2,1,2);
      imagesc( 0:ngradients-1, 0:ngradients-1, acosd(angles) ); axis xy; h = colorbar;
      xlabel('iteration'); ylabel('iteration'); ylabel( h, 'angle (deg)' );
      
    end
    
  end
  
  
  % private methods begin
  
  
  methods
    
    function this = init( this )
      % Compute paramRanges. this.params.agentLogs has to be set before
      % calling this method.
      
      % clear old paramRanges.alpha0
      this.paramRanges.theta0 = {};
      
      % loop through log structs
      for logInd=1:numel( this.agentLogs )
        
        % pick the log and verify that it begins with initial values (episode == 0)
        log = this.agentLogs(logInd);
        assert( log.episode(1) == 0, 'Some of the logs do not start with an initial value entry (episode 0)!' );
        
        % loop through iterations
        for iteration=1:length(log.episode)-1
          
          % loop through step-sizes
          for alphaInd=1:length(this.alpha)

            % compute theta (+1 = skip initial-value episode 0)
            this.paramRanges.theta0{logInd,iteration,alphaInd} = ...
              log.theta(iteration + 1,:) + this.alpha(alphaInd) * log.Q(iteration + 1,:);
            
          end

        end
        
      end
      
      % paramRanges.theta0: reshape first dim (take shape from agentLogs), store shape, and flatten
      if isscalar( this.agentLogs )
        this.resultsShape = size(this.paramRanges.theta0);
        this.resultsShape(1) = [];
      elseif isvector( this.agentLogs )
        this.resultsShape = size(this.paramRanges.theta0);
      else
        this.resultsShape = size(this.paramRanges.theta0);
        this.resultsShape = [ size(this.agentLogs), this.resultsShape(2:end) ];
      end
      this.paramRanges.theta0 = this.paramRanges.theta0(:);
      
    end
    
  end
  
end
