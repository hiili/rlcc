function [trainer, testStats] = ...
    testGridEpisodicDInt( conf, trainer )
%TESTGRIDEPISODICDINT Test GridEisodicDoubleIntegrator


switch conf
    case 'QLearning'
        agent = AgentFltDiscretizer( ...
            AgentOnlineGreedyTD( 1, 1, 0.01, 'QLearning' ) );
    case 'TabularNAC'
        agent = AgentFltDiscretizer( ...
            TabularNAC.AgentTabularNAC( LSTDLambda( 1, 0 ) ));
end

if nargin < 2
    % construct the trainer object
    fprintf( '*** Construct the trainer object..\n' );
    trainer = Trainer( ...
        GridEpisodicDoubleIntegrator( 16, 32, 'sidepuddles' ), ...
        agent, ...
        0, 20, 100, 1000, ...  % seed, iters
        100 );                 % agent logging interval
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
