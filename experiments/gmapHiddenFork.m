function gmap = gmapHiddenFork( varargin )


% create the object
gmap = GradientMapper();

% Experiment settings
gmap.firstSeed = 1;
gmap.repeats = 2;

% generic GradientMapper settings
gmap.params.episodes = 100;
gmap.params.iterationsCIt = 10;
gmap.params.useMex = false;

% define the environment and the agent
hidden = true;
gmap.params.environment = GraphDoubleFork( 1, hidden );
gmap.params.agent = AgentNaturalActorCritic( LSTDLambda( 1, 1, ...
                                                         'I', 0, ...
                                                         'beta', 0, ...
                                                         'batchmethod', 'pinv' ));

% define the region to be mapped
theta0 = [ 0, 0 ];
axis1  = [ 1, 0 ];
axis2  = [ 0, 1 ];
axis1steps = -3:1:3;
axis2steps = -3:1:3;

% store the region
gmap.params.theta0 = theta0(:);
gmap.params.axis1 = axis1(:);
gmap.params.axis2 = axis2(:);
gmap.paramRanges.axis1step = num2cell(axis1steps);
gmap.paramRanges.axis2step = num2cell(axis2steps);

% run
gmap = run( gmap, varargin{:} );


end

