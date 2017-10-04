function expr = experimentTetris_default( varargin )
% EXPERIMENTTETRIS_DEFAULT Basic template for Tetris experiments


expr = Experiment();

expr.trainFunc = @trainTetris;

expr.firstSeed = 1;
expr.repeats = 10;


% set to e.g. 'episodes' if more detailed logging is needed
expr.params.agentLogLevel = 'iterations';

expr.params.iterations = 20;
expr.params.testEpisodes = 50;

expr.params.episodesIt = 50;
expr.params.iterationsCIt = 10;
expr.params.stepsizeA = 10;
expr.params.stepsizeC = 1;

expr.params.actor = @AgentNaturalActorCritic;
expr.params.critic = @LSPELambda;
expr.params.theta0 = 'h20';
expr.params.w0 = [];

expr.params.gamma = 0.9;
expr.params.lambda = 0.2;
expr.params.beta = 0;
expr.params.I = 1;
expr.params.thetaC = Inf;


expr.paramRanges.gamma = {0.8 0.9 0.95};

expr.paramRanges.lambda = {0 1};
expr.paramValueLabels.lambda = {'TD', 'MC'};


expr = run( expr, varargin{:} );


end
