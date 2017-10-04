function [trainer, testStats] = ...
    testGraphTDCross( conf, trainer )
%TESTGRAPHTDCROSS ...


switch conf
    case 'QLearning'
        agent = AgentOnlineGreedyTD( 1, 0.1, 0.1, 'QLearning' );
    case 'TabularNAC'
        agent = TabularNAC.AgentTabularNAC( LSTDLambda( 1, 0 ) );
end

if nargin < 2
    % construct the trainer object
    fprintf( '*** Construct the trainer object..\n' );
    trainer = Trainer( ...
        GraphTDCross(), ...
        agent, ...
        0, 100, 10, 100, ...   % seed, iters
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
    'visEnvironment', true, 'visEnvironmentStats', false );
fprintf( '*** Visualizing done.\n\n' );

% get stats
fprintf( '*** Computing stats from test..\n' );
testStats = getStats( trainer.results.envTest );
fprintf( '*** Stats computed.\n' );


end
