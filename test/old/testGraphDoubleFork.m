function [trainer, testStats] = ...
    testGraphDoubleFork( conf, trainer )
%TESTGRAPHDOUBLEFORK ...


switch conf
    case 'QLearning'
        agent = AgentOnlineGreedyTD( 1, 1, 0.1, 0.1, 'QLearning' );
    case 'SARSA'
        agent = AgentOnlineGreedyTD( 1, 1, 0.1, 0.1, 'SARSA' );
    case 'TabularNAC'
        agent = TabularNAC.AgentTabularNAC( LSTDLambda( 1, 0 ) );
    case 'NAC'
        agent = AgentNaturalActorCritic( LSTDLambda( 1, 1, ...
                                                     'I', 0, ...
                                                     'beta', 0, ...
                                                     'batchmethod', 'pinv' ), ...
                                         'stepsize', [2 1] );
end

if nargin < 2
    % construct the trainer object
    fprintf( '*** Construct the trainer object..\n' );
    trainer = Trainer( ...
        GraphDoubleFork( 1, true ), agent, 1, ... % seed
        25, 50, 1, 50, ...   % iters
        1 );                   % agent logging interval
    fprintf( '*** Done constructing the trainer object.\n\n' );

    % run it
    fprintf( '*** Running the trainer..\n' );
    trainer = run( trainer );
    fprintf( '*** Finished running the trainer.\n\n' );
end

% visualize
fprintf( '*** Visualizing..\n' );
visualize( trainer, ...
    'visEnvironment', false, 'visEnvironmentStats', false );
fprintf( '*** Visualizing done.\n\n' );

% get stats
fprintf( '*** Computing stats from test..\n' );
testStats = getStats( trainer.results.envTest );
fprintf( '*** Stats computed.\n' );


end
