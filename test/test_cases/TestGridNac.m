classdef TestGridNac < Test
  %TESTGRIDCNAC Test GridEpisodicBasic with NAC
  
  
  properties
    
    % parameters
    params = struct( ...
      'environment', GridEpisodicBasic(10,10,'middlepuddle'), ...
      'agent', 'NAC', ...
      'iterations', 5, ...
      'episodesIt', 25, ...
      'stepsizeA', 10, ...
      'actor', @AgentNaturalActorCritic, ...
      'critic', @LSPELambda );
    
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
