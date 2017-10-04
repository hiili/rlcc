function trainer = trainTetris( varargin )
%TRAINTETRIS Train an agent in the Tetris environment
%
%   t = trainTetris();
%   t = trainTetris( 'theta0', 'h20', 'w0', zeros(1,45) );
%   t = trainTetris( params );




% parse args

args = inputParser;

args.addParamValue( 'seed', 1, @(x) (isnumeric(x) && isscalar(x)) );
args.addParamValue( 'conf', 'actor-critic', @ischar );

args.addParamValue( 'logLevel', 'iterations', @ischar );
args.addParamValue( 'useMex', true, @islogical );

args.addParamValue( 'iterations', 10, @(x) (isnumeric(x) && isscalar(x)) );
args.addParamValue( 'trainTestEpisodes', 0, @(x) (isnumeric(x) && isscalar(x)) );
args.addParamValue( 'testEpisodes', 0, @(x) (isnumeric(x) && isscalar(x)) );

args.addParamValue( 'trainMaxSteps', Inf, @(x) (isnumeric(x) && isscalar(x)) );
args.addParamValue( 'trainMinReturn', -Inf, @(x) (isnumeric(x) && isscalar(x)) );
args.addParamValue( 'trainMaxReturn', Inf, @(x) (isnumeric(x) && isscalar(x)) );
args.addParamValue( 'stopConds', [], @(x) (isstruct(x) || isempty(x)) );   % set both training and testing stopconds
                                                                           % (overrides the preceding settings)

args.addParamValue( 'episodesIt', 100, @(x) (isnumeric(x) && isscalar(x)) );   % episodes per actor iteration
args.addParamValue( 'iterationsCIt', 10, @(x) (isnumeric(x) && isscalar(x)) );   % critic iterations per actor iteration
                                                                                 % (allows LSPI-like operation)
args.addParamValue( 'stepsizeA', 10, @(x) (isnumeric(x) && isvector(x) && length(x) <= 2) );
args.addParamValue( 'stepsizeC', 1, @(x) (isnumeric(x) && isscalar(x)) );

args.addParamValue( 'actor', @AgentNaturalActorCritic, @(x) (isa( x, 'function_handle' )) );
args.addParamValue( 'critic', @LSPELambda, @(x) (isa( x, 'function_handle' )) );
args.addParamValue( 'theta0', 'h50', @(x) (ischar(x) || isnumeric(x)) );
args.addParamValue( 'w0', [], @isnumeric );
args.addParamValue( 'criticBatchMethod', 'pinv', @ischar );
args.addParamValue( 'criticFeatureMask', ...
  logical([ ...   % disable advantage bias (second to last feature) and irf (last feature)
    1 1 1 1 1 1 1 1 1 1   1 1 1 1 1 1 1 1 1   1 1 1 ...
    1 1 1 1 1 1 1 1 1 1   1 1 1 1 1 1 1 1 1   1 1 0 0 ]), ...
  @islogical );

args.addParamValue( 'gamma', 0.9, @(x) (isnumeric(x) && isscalar(x)) );
args.addParamValue( 'lambda', 0.2, @(x) (isnumeric(x) && isscalar(x)) );
args.addParamValue( 'betaA', 1, @(x) (isnumeric(x) && isscalar(x)) );   % actor forgetting factor
args.addParamValue( 'betaC', 0, @(x) (isnumeric(x) && isscalar(x)) );   % critic forgetting factor
args.addParamValue( 'tau', 1, @(x) (isnumeric(x) && isscalar(x)) );   % policy temperature
args.addParamValue( 'I', 1, @(x) (isnumeric(x) && isscalar(x)) );
args.addParamValue( 'thetaC', Inf, @(x) (isnumeric(x) && isscalar(x)) );
args.addParamValue( 'QInterpretation', 'gradient', @ischar );   % 'gradient' or 'target'

args.addParamValue( 'actorArgs', {}, @iscell );
args.addParamValue( 'criticArgs', {}, @iscell );

args.parse( varargin{:} );
p = args.Results;


% set options
visualization = -1;


% handle theta0 presets
if ischar(p.theta0)
  [p.theta0, w0] = TetrisPresets( p.theta0 );
  if isempty(p.w0); p.w0 = [w0; zeros(size(p.theta0))]; end
end




% select the trainer configuration

switch p.conf
  
  
  % test configs
  
  case 'test_Tetris'
    p.environment = Tetris( 20, 10, 'visualize', visualization );
    p.agent = AgentRandom();
  case 'test_Tetris_stdfeats'
    p.environment = TetrisStandardFeatures( 20, 10, 'visualize', visualization );
    p.agent = AgentRandom();
  
  
  % main actor-critic config
  
  case 'actor-critic'
    p.environment = TetrisStandardFeatures( 20, 10, 'visualize', visualization );
    p.agent = p.actor( p.critic( p.gamma, p.lambda, ...
                                 'I', p.I, ...
                                 'beta', p.betaC, ...
                                 'stepsize', p.stepsizeC, ...
                                 'iterations', p.iterationsCIt, ...
                                 'w0', p.w0, ...
                                 'batchMethod', p.criticBatchMethod, ...
                                 'featureMask', p.criticFeatureMask, ...
                                 p.criticArgs{:} ), ...
                       'thetaC', p.thetaC, ...
                       'beta', p.betaA, ...
                       'tau', p.tau, ...
                       'QInterpretation', p.QInterpretation, ...
                       'stepsize', p.stepsizeA, ...
                       'theta0', p.theta0, ...
                       p.actorArgs{:} );
  
 
  % experimental configs (outdated)
  
  case 'NAC-greedy'
    greediness = 1e6;
    environment = TetrisStandardFeatures( 20, 10, 'visualize', visualization );
    agent = AgentHybridNAC( LSTDLambda( p.gamma, p.lambda, ...
                                                 'I', p.I, ...
                                                 'beta', p.beta, ...
                                                 'batchmethod', 'pinv' ), ...
                            'stepsize', p.stepsizeA, ...
                            'theta0', greediness * p.theta0, ...
                            'greediness', greediness );
  case 'LSPI'
    useAdvantages = false;
    environment = TetrisStandardFeatures( 20, 10, 'visualize', visualization );
    agent = AgentLSPI( LSTDLambda( p.gamma, p.lambda, ...
                                   'I', p.I, ...
                                   'batchmethod', 'pinv' ), ...
                       'use_advantages', useAdvantages, ...
                       'w0', p.w0(1:end/2) );   % !!! BROKEN: w0 is now state dim + state-action dim
  case 'LSLPI'
    useAdvantages = false;
    environment = TetrisStandardFeatures( 20, 10, 'visualize', visualization );
    agent = AgentLSLambdaPI( LSTDLambda( p.gamma, p.lambda, ...
                                         'I', p.I, ...
                                         'batchmethod', 'pinv' ), ...
                             'use_advantages', useAdvantages, ...
                             'w0', p.w0(1:end/2) );   % !!! BROKEN: w0 is now state dim + state-action dim
  
  otherwise
    error('Unknown configuration ''%s''', p.conf);
  
end




% configure

trainer = Trainer();

% basic trainer configuration
trainer.seed = p.seed;
trainer.logLevel = p.logLevel;
trainer.environment = p.environment;
trainer.agent = p.agent;

% prepare stopping conditions struct
stopConds.train.maxSteps = p.trainMaxSteps;
stopConds.train.totalRewardRange(1) = p.trainMinReturn;
stopConds.train.totalRewardRange(2) = p.trainMaxReturn;
if ~isempty( p.stopConds ); stopConds = p.stopConds; end

% configure training
trainer.training.iterations = p.iterations;
trainer.training.evaluation.iterations = p.episodesIt;
trainer.training.evaluation.episodeStoppingConditions = stopConds.train;
trainer.training.evaluation.useMex = p.useMex;

% configure during-training testing
trainer.trainingTest.iterations = p.iterations;
trainer.trainingTest.evaluation.iterations = p.trainTestEpisodes;
trainer.trainingTest.evaluation.useMex = p.useMex;

% configure testing
trainer.testing.iterations = p.testEpisodes;
trainer.testing.useMex = p.useMex;




% run
trainer.run();




end
