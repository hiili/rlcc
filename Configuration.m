classdef Configuration
  %CONFIGURATION Global configuration settings
  %
  %   Global configuration settings. The settings are grouped by the name
  %   of the class in which the configuration setting is (mainly) used.
  %
  %   NOTE: You have to do 'clear classes' so as to apply any changes!
  %
  %   For configuring mex implementations, see:
  %     src/mex/*/Configuration.hpp
  %   Summary:
  %     Tetris: #define TERMINAL_BIAS_VALUE_S
  %     Tetris: #define TERMINAL_BIAS_VALUE_A
  %     AgentNaturalActorCritic: #define REJECT_TERMINAL_ACTIONS
  %     AgentNaturalActorCritic and LSTDLambda: const PetersTrickMode PETERS_TRICK_MODE
  
  
  %#ok<*MCCPI>

  
  properties (Constant)
    Experiment = struct( ...
      ...
      ... % If set, then the experiment is run using the parallel computing toolbox
      ... % with the specified configuration.
      ... %   (passed to the parallel computing toolbox as a configuration)
      'parallelConfiguration', 'local', ...
      ...
      ... % Path prefix to the software root directory for the parallel job workers,
      ... % if different from the path on the client machine.
      ... %   (string)
      'parallelPathPrefix', [], ...
      ...
      ... % Maximum number of task groups. If there are more tasks than
      ... % parallelMaxTaskGroups, then several tasks will be grouped into a single
      ... % parallel computing toolbox task. This is useful for a large number of
      ... % short tasks with which the overhead of full parallelization would
      ... % outweigh the benefits.
      ... %   (int)
      'parallelMaxTaskGroups', 250 );
      
  end
  
end
