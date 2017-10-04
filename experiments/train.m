function trainer = train( varargin )
%TRAIN A generic user interface for the training process




% parse args

args = inputParser;

args.addParamValue( 'seed', 1, @(x) (isnumeric(x) && isscalar(x)) );
args.addParamValue( 'environment', [], @(x) (isa(x, 'Environment')) );
args.addParamValue( 'agent', 'NAC', @ischar );

args.addParamValue( 'logLevel', 'iterations', @ischar );

args.addParamValue( 'iterations', 10, @(x) (isnumeric(x) && isscalar(x)) );
args.addParamValue( 'trainTestEpisodes', 0, @(x) (isnumeric(x) && isscalar(x)) );
args.addParamValue( 'testEpisodes', 0, @(x) (isnumeric(x) && isscalar(x)) );

args.addParamValue( 'trainMaxSteps', Inf, @(x) (isnumeric(x) && isscalar(x)) );
args.addParamValue( 'testMaxSteps', Inf, @(x) (isnumeric(x) && isscalar(x)) );
args.addParamValue( 'stopConds', [], @(x) (isstruct(x) || isempty(x)) );   % set both training and testing stopconds
                                                                           % (overrides the preceding settings)

args.addParamValue( 'episodesIt', 100, @(x) (isnumeric(x) && isscalar(x)) );   % episodes per actor iteration
args.addParamValue( 'iterationsCIt', 10, @(x) (isnumeric(x) && isscalar(x)) );   % critic iterations per actor iteration
                                                                                 % (allows LSPI-like operation)
args.addParamValue( 'stepsizeA', 10, @(x) (isnumeric(x) && isvector(x) && length(x) <= 2) );
args.addParamValue( 'stepsizeC', 1, @(x) (isnumeric(x) && isscalar(x)) );

args.addParamValue( 'actor', @AgentNaturalActorCritic, @(x) (isa( x, 'function_handle' )) );
args.addParamValue( 'critic', @LSPELambda, @(x) (isa( x, 'function_handle' )) );
args.addParamValue( 'theta0', [], @(x) (ischar(x) || isnumeric(x)) );
args.addParamValue( 'w0', [], @isnumeric );
args.addParamValue( 'criticBatchMethod', 'pinv', @ischar );

args.addParamValue( 'gamma', 1, @(x) (isnumeric(x) && isscalar(x)) );
args.addParamValue( 'lambda', 0, @(x) (isnumeric(x) && isscalar(x)) );
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




% configure the agent

switch p.agent
  case 'QLearning'
    p.agent = AgentOnlineGreedyTD( p.gamma, p.lambda, p.stepsizeC, p.tau, 'QLearning' );
  case 'SARSA'
    p.agent = AgentOnlineGreedyTD( p.gamma, p.lambda, p.stepsizeC, p.tau, 'SARSA' );
  case 'NAC'
    p.agent = p.actor( p.critic( p.gamma, p.lambda, ...
                                 'I', p.I, ...
                                 'beta', p.betaC, ...
                                 'stepsize', p.stepsizeC, ...
                                 'iterations', p.iterationsCIt, ...
                                 'w0', p.w0, ...
                                 'batchMethod', p.criticBatchMethod, ...
                                 p.criticArgs{:} ), ...
                       'thetaC', p.thetaC, ...
                       'beta', p.betaA, ...
                       'tau', p.tau, ...
                       'QInterpretation', p.QInterpretation, ...
                       'stepsize', p.stepsizeA, ...
                       'theta0', p.theta0, ...
                       p.actorArgs{:} );
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
stopConds.train.totalRewardRange = [-Inf, Inf];
stopConds.test.maxSteps = p.testMaxSteps;
stopConds.test.totalRewardRange = [-Inf, Inf];
if ~isempty( p.stopConds ); stopConds = p.stopConds; end

% configure training
trainer.training.iterations = p.iterations;
trainer.training.evaluation.iterations = p.episodesIt;
trainer.training.evaluation.episodeStoppingConditions = stopConds.train;

% configure during-training testing
trainer.trainingTest.iterations = p.iterations;
trainer.trainingTest.evaluation.iterations = p.trainTestEpisodes;
trainer.trainingTest.evaluation.episodeStoppingConditions = stopConds.test;

% configure testing
trainer.testing.iterations = p.testEpisodes;
trainer.testing.episodeStoppingConditions = stopConds.test;


% add state visitation distribution logging if the environment supports it
if ~isempty( fieldnames(p.environment.getStats()) )
  trainer.logger.addRules( 'name', 'environment', 'trigger', {'training', 'trainingTest', 'testing'}, ...
                           'target', 'environment', 'interval', {'(]', '(]', '(]='}, ...
                           'command', 'target.getStats()' );
  trainer.logger.addRules( 'name', 'environmentReset', 'trigger', {'training', 'trainingTest', 'testing'}, ...
                           'target', 'environment', 'interval', {'(]', '(]', '(]='}, ...
                           'command', 'target.resetStats()', 'logMode', 'none' );
end




% run
trainer.run();




end
