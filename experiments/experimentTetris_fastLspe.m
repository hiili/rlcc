function expr = experimentTetris_fastLspe( varargin )
% EXPERIMENTTETRIS_FASTLSPE Search for the fastest convergence with LSPE


expr = Experiment();

expr.trainFunc = @trainTetris;

expr.firstSeed = 1;
expr.repeats = 20;


expr.params.agentLogLevel = 'iterations';

expr.params.iterations = 20;
expr.params.testEpisodes = 50;

expr.params.episodesIt = 10;
expr.params.iterationsCIt = 10;
expr.params.stepsizeA = 5;
expr.params.stepsizeC = 1;

expr.params.actor = @AgentNaturalActorCritic;
expr.params.critic = @LSPELambda;
expr.params.theta0 = 'h20b';
expr.params.w0 = zeros(1,44);

expr.params.gamma = 0.9;
expr.params.lambda = 0.5;
expr.params.beta = 0;
expr.params.I = 1;
expr.params.thetaC = Inf;


expr.paramRanges.episodesIt = {5, 7, 10, 15};
expr.paramRanges.stepsizeA = {2, 5, 7.5, 10, 15};
expr.paramRanges.lambda = {0, 0.25, 0.5, 0.75, 1};
expr.paramRanges.beta = {0, 0.25, 0.5};
expr.paramRanges.I = {0, 0.5, 1, 2, 4};

expr = run( expr, varargin{:} );


end
