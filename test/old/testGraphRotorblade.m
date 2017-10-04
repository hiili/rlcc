function [trainer, testStats] = ...
    testGraphRotorblade( conf, trainer )
%TESTGRAPHTHREEPHASEMOTORDET ...


switch conf
    case 'QLearning'
        agent = AgentOnlineGreedyTD( 1, 0, 0.1, 0.1, 'QLearning' );
    case 'SARSA'
        agent = AgentOnlineGreedyTD( 1, 0, 0.1, 0.1, 'SARSA' );
    case 'TabularNAC'
        agent = TabularNAC.AgentTabularNAC( LSTDLambda( 1, 0 ) );
    case 'NAC'
        agent = AgentNaturalActorCritic( LSTDLambda( 1, 0, ...
                                                     'I', 0, ...
                                                     'beta', 0, ...
                                                     'batchmethod', 'pinv' ), ...
                                         'stepsize', 1 );
end

if nargin < 2
    % construct the trainer object
    fprintf( '*** Construct the trainer object..\n' );
    trainer = Trainer( ...
        GraphRotorblade(), agent, 1, ... % seed
        50, 50, 1, 50, ...   % iters
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

alogs = getLogs( trainer.results.agent );
Qs1 = alogs.Q(:,[1, 6, 11]);
figure;
imagesc( Qs1' );
colormap bone; colorbar; title( 'Q_{s1}' );

fprintf( '*** Visualizing done.\n\n' );


% get stats
fprintf( '*** Computing stats from test..\n' );
testStats = getStats( trainer.results.envTest );
fprintf( '*** Stats computed.\n' );


end
