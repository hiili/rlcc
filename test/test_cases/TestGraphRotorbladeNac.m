classdef TestGraphRotorbladeNac < Test
  %TESTGRAPHROTORBLADENAC Tests the graph environment with NAC
  %
  %   Tests the general operation of GraphGeneric, as well as the
  %   state-dependent action range stuff (not systematically, though).
  
  
  properties
    
    % parameters
    params = struct( ...
      'environment', GraphRotorblade(), ...
      'agent', 'NAC', ...
      'iterations', 20, ...
      'stepsizeA', 1, ...
      'actor', @AgentNaturalActorCritic, ...
      'critic', @LSPELambda, ...
      'lambda', nan );
    
    % parameter ranges
    paramRanges = struct( ...
      'lambda', {{0.1, 0.9}} );
    
  end
  
  methods
    
    function expr = run( this )
      
      expr = Experiment();
      expr.trainFunc = @train;
      expr.firstSeed = 1;
      expr.repeats = 2;
      expr.params = this.params;
      expr.paramRanges = this.paramRanges;
      
      run( expr );
      
    end
    
  end
  
end

