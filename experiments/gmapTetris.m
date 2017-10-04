function gmap = gmapTetris( varargin )


% create the object
gmap = GradientMapper();

% Experiment settings
gmap.firstSeed = 1;
gmap.repeats = 5;

% generic GradientMapper settings
gmap.params.episodes = 1000;
gmap.params.iterationsCIt = 20;
gmap.params.useMex = true;

% define the environment and the agent
gamma = 0.99;
lambda = 1;
gmap.params.environment = TetrisStandardFeatures( 20, 10, 'visualize', -1 );
gmap.params.agent = AgentNaturalActorCritic( LSTDLambda( gamma, lambda, ...
                                                         'I', 0, ...
                                                         'batchmethod', 'pinv' ));

% define the region to be mapped
theta0 = [...   % rl60
  0.2923 -0.4684 -0.0689 -0.2698 -0.2786 -0.2376 -0.1493 -0.2317 -0.4885 0.3459 ...
  -0.9277 -0.4333 -0.6222 -0.4065 -0.6442 -0.4164 -0.6487 -0.3404 -0.9073 ...
  0.8937 -3.4472 99.9077 ];
axis1 = zeros(1,22); axis1(20) = 1;
axis2 = zeros(1,22); axis2(21) = 1;
axis1steps = -5:0.5:5;
axis2steps = -5:0.5:5;

% store the region
gmap.params.theta0 = theta0(:);
gmap.params.axis1 = axis1(:);
gmap.params.axis2 = axis2(:);
gmap.paramRanges.axis1step = num2cell(axis1steps);
gmap.paramRanges.axis2step = num2cell(axis2steps);

% run
gmap = run( gmap, varargin{:} );


end

