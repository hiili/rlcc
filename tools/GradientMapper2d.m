classdef GradientMapper2d < Experiment
  % GRADIENTMAPPER2D Map an environment-agent pair around some parameter values
  %
  %   Map the gradient and return landscape of an environment-agent pair
  %   around some parameter values. The mapping is performed on a
  %   two-dimensional grid in the policy parameter space.
  %
  %   The training parameters and the grid are defined by filling in the
  %   properties from the inherited Experiment class listed below. See also
  %   other properties inherited from Experiment.
  % 
  %   The mapping process is started with the method
  %   GradientMapper2d.run(). The returns can be found in the Experiment
  %   property 'returnsTrain'. The gradients can be found in the
  %   GradientMapper2d property 'gradients'. Some aspects of the results
  %   can be visualized using the method GradientMapper2d.visualize().
  %
  %   Accepted fields for the inherited Experiment.params property:
  %
  %     (Environment) environment, (Agent) agent
  %       The environment and the agent objects.
  %
  %     (int) episodes
  %       Number of training episodes.
  %
  %     (logical) useMex
  %       Whether to use a mex implementation.
  %
  %     (string) coordinateSystem = 'cartesian' | 'polar'
  %       If 'cartesian', then the axis1step and axis2step arrays are
  %       interpreted as axis1 and axis2 coordinates, respectively. If
  %       'polar', then axis1step is interpreted as the radius and
  %       axis2step as the angle on the sampling plane (angle == 0 points
  %       along axis1 and angle == pi/2 points along axis2). If using the
  %       polar system, it might be useful to scale axis2 so as to adjust
  %       the covered distance in that direction. Default: 'cartesian'
  %
  %     (column double array) theta0
  %       Origin of the region to be mapped.
  %
  %     (length(theta0) -element column double array) axis1, axis2
  %       The directions of the two axes. These do not need to be
  %       normalized.
  %
  %   Accepted fields for the inherited Experiment.paramRanges property:
  %
  %     (cell array of doubles) axis1step, axis2step
  %       Define the grid points relative to the axes.
  %
  %   See also Experiment
  
  % TODO Consider merging with GradientMapper.
  
  %#ok<*AGROW,*PROP>
  
  
  properties
    
    % Final gradient estimates for each gridpoint and repeat. First two
    % dimensions correspond to axes. The repeats run along the third
    % dimension. The gradient vectors run along the fourth dimension.
    % Filled in run().
    %   (4-dimensional double array)
    gradients;
    
  end
  
  
  methods
    
    % Constructor
    function this = GradientMapper2d()
      
      % set GradientMapper2d defaults
      this.params.episodes = 100;
      this.params.useMex = false;
      this.params.coordinateSystem = 'cartesian';   % 'cartesian' or 'polar'
      
      % set Experiment defaults
      this.trainFunc = @this.train;
      
    end
    
    % Start the mapping process. Arguments are passed directly to Experiment.run().
    function this = run( this, varargin )
      
      % run the experiment
      run@Experiment( this, varargin{:} );
      
      % check for errors
      if ~isempty(this.errorJob); return; end
      
      % add gradients: loop through the region and repeats
      fprintf('\nGradientMapper2d: Collecting gradients..');
      results = this.results;   % avoid a pre-2011a(?) matlab performance issue
      for a1=1:size(results, 1)
        for a2=1:size(results, 2)
          for rep=1:size(results, 3)
            
            % collect the gradients (Q dimensions: the first and the only iteration, the only
            % episode, the entire gradient vector)
            gradients(a1,a2,rep,:) = results(a1,a2,rep).trainer.logger.logs.training.evaluation.Q(1,end,:);
            
          end
        end
      end
      this.gradients = gradients;   % avoid a pre-2011a(?) matlab performance issue
      fprintf(' done\n');
      
    end
    
    function visualize( this, varargin )
      % Visualize the mapping results.
      %
      %   this.visualize( <name/value pairs> ... )
      %
      %   'showStd', (logical) showStd
      %     Whether to also produce a standard deviation plot. Default: false
      %
      %   'showGradients', (logical) showGradients
      %     Whether to superimpose the gradient field on top of the
      %     performance landscape. Default: false
      %
      %   'xScale', (string) xScale = 'linear' | 'log'
      %   'yScale', (string) yScale = 'linear' | 'log'
      %     Scaling of the axes. In case of logarithmic plotting, both axes
      %     are shifted by +1, so as to keep the origin fixed.
      %     Consequently, the accepted range for logarithmic axes is
      %     [0,Inf). With polar plotting (which is activated automatically
      %     for polar data), setting xScale to 'log' gives a log-polar
      %     plot. yScale cannot be set to 'log' with polar plotting.
      %
      %   'allTicks', (logical) allTicks
      %     Whether to annotate each and every sampling point along the
      %     axis. Setting this to true might make the figure cluttered.
      %     Default: false
      %
      %   'dontLogScaleGradients', (logical) dontLogScaleGradients
      %     If true, then the gradient field vectors are shown in
      %     linear-polar coordinates even if the plot is log-polar.
      %     Default: false
      %
      %   'gradientMagnitudeStd', (logical) gradientMagnitudeStd
      %     If true, then the lengths of the gradient field vectors is used
      %     to encode the uncertainty in the estimates. Default: false
      
      % TODO gradientMagnitudeStd: normalize all gradient vectors _before_
      % averaging them. this would directly encode the uncertainty into the
      % length of the vectors.
      
      
      % parse arguments
      args = inputParser;
      args.addParamValue( 'showStd', false, @(x) (islogical(x) && isscalar(x)) );
      args.addParamValue( 'showGradients', false, @(x) (islogical(x) && isscalar(x)) );
      args.addParamValue( 'xScale', 'linear', @(x) (any(strcmp(x,{'linear','log'}))) );
      args.addParamValue( 'yScale', 'linear', @(x) (any(strcmp(x,{'linear','log'}))) );
      args.addParamValue( 'allTicks', false, @(x) (islogical(x) && isscalar(x)) );
      args.addParamValue( 'dontLogScaleGradients', false, @(x) (islogical(x) && isscalar(x)) );
      args.addParamValue( 'gradientMagnitudeStd', false, @(x) (islogical(x) && isscalar(x)) );
      
      args.parse( varargin{:} );
      args = args.Results;
      
      % set constants
      quiverStyle = 'k';   % gradient field arrowstyle
      
      % clear figure
      clf;
      
      
      % --- set up the data and the coordinate system
      
      % extract data
      axis1 = this.params.axis1 / norm(this.params.axis1);
      axis2 = this.params.axis2 / norm(this.params.axis2);
      axis1stepsUnscaled = cell2mat(this.paramRanges.axis1step);
      axis2stepsUnscaled = cell2mat(this.paramRanges.axis2step);
      returns_mean = mean(this.returnsTrain,3);
      returns_std = std(this.returnsTrain,0,3) / sqrt(size(this.returnsTrain,3));   % standard deviation of the mean
      gradients = this.gradients;
      
      % apply logarithmic scaling?
      axis1steps = axis1stepsUnscaled;
      axis2steps = axis2stepsUnscaled;
      switch this.params.coordinateSystem
        case 'cartesian'
          if strcmp(args.xScale, 'log'); assert(all(axis1stepsUnscaled >= 0)); axis1steps = axis1stepsUnscaled + 1; end
          if strcmp(args.yScale, 'log'); assert(all(axis2stepsUnscaled >= 0)); axis2steps = axis2stepsUnscaled + 1; end
        case 'polar'
          if strcmp(args.xScale, 'log')
            assert(all(axis1stepsUnscaled >= 0));
            axis1steps = log(axis1stepsUnscaled + 1);   % shift by +1 to keep origin fixed
          end
          if strcmp(args.yScale, 'log'); error('yScale cannot be logarithmic in polar plots.'); end
        otherwise; assert(false);
      end
      
      % axis steps form a grid whose cell corners define the sampling
      % points. compute the mesh grid for surf() for which the sampling
      % points fall at the centers of the grid cells.
      xSurf = interp1( 1:length(axis1steps), axis1steps, 0.5:length(axis1steps)+0.5, 'pchip' );
      ySurf = interp1( 1:length(axis2steps), axis2steps, 0.5:length(axis2steps)+0.5, 'pchip' );
      if strcmp(args.xScale, 'log'); xSurf(1) = max(xSurf(1),eps); end   % avoid clipping
      if strcmp(args.yScale, 'log'); ySurf(1) = max(ySurf(1),eps); end
      
      % create data point and surface vertex meshes
      [xMesh, yMesh] = meshgrid( axis1steps, axis2steps );
      [xSurfMesh, ySurfMesh] = meshgrid( xSurf, ySurf );
      
      % if should interpret as polar, then convert to cartesian
      if strcmp(this.params.coordinateSystem, 'polar')
        [xMesh, yMesh] = pol2cart( yMesh, xMesh );
        [xSurfMesh, ySurfMesh] = pol2cart( ySurfMesh, xSurfMesh );
      end
      
      
      % --- plot the return landscape
      
      % split the plot?
      if args.showStd; subplot(1,2,1); end
      
      % choose data
      Z = returns_mean;
      Z(end+1,:) = NaN; Z(:,end+1) = NaN;   % add dummy values to the outer edge, surf() needs these
      
      % plot (requires a patched matlab2tikz)
      surf( xSurfMesh, ySurfMesh, zeros(size(Z')), Z' );
      this.setImageProps( axis1stepsUnscaled, axis2stepsUnscaled, axis1steps, axis2steps, args );
      
      
      % --- plot the standard deviation of the return landscape estimate
      
      if args.showStd
        subplot(1,2,2);
        
        % choose data
        Z = returns_std;
        Z(end+1,:) = NaN; Z(:,end+1) = NaN;   % add dummy values to the outer edge, surf() needs these

        % plot (requires a patched matlab2tikz)
        surf( xSurfMesh, ySurfMesh, zeros(size(Z')), Z' );
        this.setImageProps( axis1stepsUnscaled, axis2stepsUnscaled, axis1steps, axis2steps, args );
        title('returns stddev');
        
      end
      
      
      % --- plot the gradient field
      
      if args.showGradients
        
        % compute gradient projections to the axes
        gr = squeeze1( mean(gradients,3), 3 );
        grStd = squeeze1( std(gradients,0,3), 3 ) / sqrt(size(this.returnsTrain,3));   % standard deviation of the mean
        for i=1:size(gr,1)
          for j=1:size(gr,2)
            grProj(i,j,:) = squeeze(gr(i,j,:))' * [axis1, axis2];
            grStdProj(i,j,:) = squeeze(grStd(i,j,:))' * [axis1, axis2];
          end
        end
        
        % apply log mapping? (needs to be done manually with polar plots)
        if strcmp(this.params.coordinateSystem,'polar') && strcmp(args.xScale, 'log') && ~args.dontLogScaleGradients
          
          % compute gradient vector end points
          [xMeshGr0, yMeshGr0] = meshgrid( axis1stepsUnscaled, axis2stepsUnscaled );   % gradient vector bases, unscaled
          [xMeshGr0, yMeshGr0] = pol2cart( yMeshGr0, xMeshGr0 );   % convert from polar to cartesian
          xMeshGr1 = xMeshGr0 + grProj(:,:,1)';   % gradient vector tips, unscaled, cartesian
          yMeshGr1 = yMeshGr0 + grProj(:,:,2)';
          
          % apply log scaling to radii (shift by +1, just as was done for the main grid)
          [th, r] = cart2pol( xMeshGr1, yMeshGr1 );
          [xMeshGr1, yMeshGr1] = pol2cart( th, log(r + 1) );
          
          % convert absolute end points back to relative vectors
          grProj(:,:,1) = (xMeshGr1 - xMesh)';
          grProj(:,:,2) = (yMeshGr1 - yMesh)';
          
        end
        
        % encode uncertainty in gradient length?
        if args.gradientMagnitudeStd
          grProj = bsxfun( @rdivide, grProj, sqrt( grProj(:,:,1).^2 + grProj(:,:,2).^2 ) );   % normalize
          grProj = bsxfun( @times, grProj, sqrt( grStdProj(:,:,1).^2 + grStdProj(:,:,2).^2 ) );   % scale by sdom
        end
        
        % plot the projected gradient field
        if args.showStd; subplot(1,2,1); end
        hold on;
        quiver( xMesh, yMesh, grProj(:,:,1)', grProj(:,:,2)', quiverStyle );

        % plot the standard deviation of the projected gradient field estimate (rather noninformative due to scaling)
        if args.showStd
          subplot(1,2,2); hold on;
          quiver( xMesh, yMesh, grStdProj(:,:,1)', grStdProj(:,:,2)', quiverStyle );
        end
        
      end
      
    end
    
  end
  
  
  % private methods begin
  
  
  methods (Static, Access=private)
    
    % Evaluate at the specified gridpoint.
    function trainer = train( params )
      
      % take new copies of the environment and the agent
      environment = clone( params.environment );
      agent = clone( params.agent );

      % set the sampling point in parameter space
      switch params.coordinateSystem
        case 'cartesian'
          x = params.axis1step;
          y = params.axis2step;
        case 'polar'
          % axis1step = radius, axis2step = angle
          [x,y] = pol2cart( params.axis2step, params.axis1step );
        otherwise
          error('Unknown coordinate system mode: ''%s''', params.coordinateSystem);
      end
      agent.setTheta0( params.theta0(:) + x * params.axis1(:) + y * params.axis2(:) );
      
      % prepare trainer
      trainer = Trainer( 'environment', environment, 'agent', agent, 'seed', params.seed );
      trainer.logLevel = 'iterations';
      trainer.training.iterations = 1;
      trainer.training.evaluation.iterations = params.episodes;
      trainer.training.evaluation.useMex = params.useMex;
      trainer.trainingTest.evaluation.iterations = 0;
      trainer.testing.iterations = 0;
      
      % run
      trainer.run();
      
    end
    
  end
  
  
  methods (Access=private)
    
    function setImageProps( this, axis1stepsUnscaled, axis2stepsUnscaled, axis1steps, axis2steps, args )
      
      % set colors, make black gradient field visible if one is being drawn
      colormap hot;
      if args.showGradients
        colormap( colormap ./ 2 + 0.5 );
      end
      
      % set image properties
      if strcmp(this.params.coordinateSystem, 'cartesian')
        if strcmp(args.xScale, 'log'); set(gca,'XScale', 'log'); end
        if strcmp(args.yScale, 'log'); set(gca,'YScale', 'log'); end
      end
      h = colorbar; ylabel( h, 'return' );
      title('returns');
      view(2); axis tight; shading flat;
      if strcmp(this.params.coordinateSystem, 'polar'); axis square; end
      
      if args.allTicks
        if strcmp(this.params.coordinateSystem,'polar')
          error('Option ''allTicks'' cannot be used with polar plots.');
        end
        format_ticks( gca, ...
          cellfun(@(x)( num2str(x,2) ), num2cell(axis1stepsUnscaled), 'UniformOutput', false), ...
          cellfun(@(x)( num2str(x,2) ), num2cell(axis2stepsUnscaled), 'UniformOutput', false), ...
          axis1steps, axis2steps, 45, 0 );
      else
        
        xlabel('axis 1'); ylabel('axis 2');
        
        if strcmp(this.params.coordinateSystem,'polar')
          
          % draw polar grid
          arc_radii = min(axis1steps) : (max(axis1steps)-min(axis1steps))/6 : max(axis1steps);
          arc_thetas = (min(axis2steps) : (max(axis2steps)-min(axis2steps))/6 : max(axis2steps));
          %tmp = arc_radii(2) - arc_radii(1);
          %arc_radii_minor = ...
          %  sort([ arc_radii(2:end) - tmp/2, arc_radii(2:end) - tmp/4, ...
          %  arc_radii(2:end) - tmp/8, arc_radii(2:end) - tmp/16 ]);
          
          hold on;
          %arrayfun( @(r)( ellipse( 0,0, r,r, 0, minmax(arc_thetas), 'Color', 'black' ) ), arc_radii );
          arrayfun( @(r)( ellipse( 0,0, r,r, 0, minmax(arc_thetas), 'Color', 'white', 'LineStyle', ':' ) ), arc_radii );
          %arrayfun( @(r)( ellipse( 0,0, r,r, 0, minmax(arc_thetas), 'Color', [0.5 0.5 0.5], 'LineStyle', ':' ) ), arc_radii_minor );
          %arrayfun( @(th)( polar( [th th], minmax(arc_radii), 'k' ) ), arc_thetas );
          arrayfun( @(th)( polar( [th th], minmax(arc_radii), 'w:' ) ), arc_thetas );
          set( gca, 'XTick', arc_radii );
          set( gca, 'XTickLabel', sprintf('%.3g|', get(gca,'XTick')) );
          
          % apply log mapping to tick labels? (needs to be done manually with polar plots)
          if strcmp(args.xScale, 'log')
            % set ticks according to the current view; maintaining dynamic ticks is too tricky for this need
            % (see http://undocumentedmatlab.com/blog/setting-axes-tick-labels-format/)
            set( gca, 'XTickMode', 'manual');
            set( gca, 'YTickMode', 'manual');
            set( gca, 'XTickLabel', ...
              sprintf( '%.3g|', interp1(axis1steps, axis1stepsUnscaled, get(gca,'XTick'), 'pchip') ) );
            set( gca, 'YTickLabel', ...
              sprintf( '%.3g|', interp1(axis1steps, axis1stepsUnscaled, get(gca,'YTick'), 'pchip') ) );
          end

        end
        
      end
      
    end
    
  end
  
end
