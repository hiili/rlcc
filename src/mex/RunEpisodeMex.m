function RunEpisodeMex( environment, agent, stopConds )
%RUNEPISODEMEX Run an episode using a mex implementation
%
%   Run a single episode using a combination of an environment and an agent
%   for which a mex implementation exist.
%
%   The episode ends when the environment enters a terminal state.
%   Additional episode stopping conditions are not currently supported.

%   Information is passed from and to the agent and the environment in a
%   customized manner using Environment.mexFork(), Agent.mexFork(),
%   Environment.mexJoin() and Agent.mexJoin().


pairNames = { 'TetrisStandardFeatures-AgentNaturalActorCritic' };
pairHandles = { @TetrisNAC.MexTetrisNAC };




% find handle
pairName = [class(environment) '-' class(agent)];
assert( any(strcmp( pairName, pairNames )), ['Unknown pair: ' pairName] );
pairHandle = pairHandles{ strcmp( pairName, pairNames ) };


% prepare
[~, envData] = mexFork( environment, true );
[~, agentData] = mexFork( agent, true );

% call
try
  [envDataOut, agentDataOut] = pairHandle( envData, agentData, stopConds );
catch err
  if any(strcmp(err.identifier, {'MATLAB:UndefinedFunction','MATLAB:unassignedOutputs'}))
    fprintf( '\n\nException ''%s'' caught during MEX execution. Did you remember to compile using ''make''?\n\n', ...
      err.identifier );
  end
  rethrow(err);
end

% finalize
environment.mexJoin( envDataOut );
agent.mexJoin( agentDataOut );


end
