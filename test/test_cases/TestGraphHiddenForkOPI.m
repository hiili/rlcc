classdef TestGraphHiddenForkOPI < Test
  %TESTGRAPHHIDDENFORKOPI Test the Hidden fork and optimistic PI
  %
  %   Tests the general operation of GraphHiddenFork and code related to
  %   optimistic policy iteration (betaA, QInterpretation, tau)
  
  
  properties
    
    % parameters
    params = struct( ...
      'environment', GraphDoubleFork(4), ...
      'agent', 'NAC', ...
      'iterations', 20, ...
      'QInterpretation', 'target', ...
      'stepsizeA', [1 4], ...
      'tau', 0.2, ...
      'actor', @AgentNaturalActorCritic, ...
      'critic', @LSPELambda, ...
      'lambda', 1 );
    
    % parameter ranges
    paramRanges = struct();
    
  end
  
  methods
    
    function expr = run( this )
      
      expr = Experiment();
      expr.trainFunc = @train;
      expr.firstSeed = 1;
      expr.repeats = 4;
      expr.params = this.params;
      expr.paramRanges = this.paramRanges;
      
      run( expr );
      
    end
    
  end
  
end

