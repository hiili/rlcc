function [trainer, testStats] = ...
  testGridEpisodicBasic( algoconf, envconf, varargin )
%TESTGRIDEPISODICBASIC Test GridEisodicBasic
%
%   Example:
%     testGridEpisodicBasic( 'NAC', 'sidepuddles_endwall' )


args = inputParser;
args.addParamValue( 'trainer', [], @(x) isa(x, 'Trainer') );
args.addParamValue( 'updateinterval', 100, @(x) (isnumeric(x) && isscalar(x)) );
args.addParamValue( 'stepsize', 5, @(x) (isnumeric(x) && isscalar(x)) );
args.parse( varargin{:} );

trainer = args.Results.trainer;
updateIntv = args.Results.updateinterval;
stepsize   = args.Results.stepsize;

switch algoconf
  case 'QLearning'
    agent = AgentFltDiscretizer( AgentOnlineGreedyTD( 1, 1, 0.01, 'QLearning' ) );
  case 'TabularNAC'
    agent = AgentFltDiscretizer( TabularNAC.AgentTabularNAC( LSTDLambda( 1, 0 ), ...
                                                             'stepsize', stepsize ));
  case 'NAC'
    agent = AgentFltDiscretizer( AgentFltSparsify( ...
      AgentNaturalActorCritic( LSTDLambda( 1, 0 ), ...
                               'stepsize', stepsize )));
  case 'NAC-lookahead'
    agent = AgentFltDiscretizer( AgentFltSparsifyGridEBLookahead( ...
      AgentNaturalActorCritic( LSTDLambda( 1, 0 ), ...
                               'stepsize', stepsize )));
end

if isempty( trainer )
  % construct the trainer object
  fprintf( '*** Construct the trainer object..\n' );
  trainer = Trainer( ...
    GridEpisodicBasic( 10, 10, envconf ), ...
    agent, ...
    1, 10, updateIntv, 100, ...  % seed, iters
    updateIntv );                % agent logging interval
  fprintf( '*** Done constructing the trainer object.\n\n' );
  
  % run it
  fprintf( '*** Running the trainer..\n' );
  trainer = run( trainer );
  fprintf( '*** Finished running the trainer.\n\n' );
end


% visualize
fprintf( '*** Visualizing..\n' );
visualize( trainer, ...
  'visEnvironment', true, 'visEnvironmentStats', true );
fprintf( '*** Visualizing done.\n\n' );

% get stats
fprintf( '*** Computing stats from test..\n' );
testStats = getStats( trainer.results.envTest );
fprintf( '*** Stats computed.\n' );


end
