classdef TestTetrisNac < Test
  %TESTTETRISNAC Base class for Tetris + NAC tests
  %
  %   The Tetris environment is not explicitly tested here, although any
  %   changes will almost certainly show up also in this test.
  %
  %   Some interpolative parameters are set to slightly non-extreme values
  %   even at the cost of being suboptimal. This is so as to have in the
  %   results an effect from all involved functionality.
  
  
  properties
    
    % default parameters
    params = struct( ...
      'conf', 'actor-critic', ...
      'iterations', 10, ...
      'testEpisodes', 10, ...
      'episodesIt', 25, ...
      'iterationsCIt', 5, ...
      'stepsizeA', 50, ...
      'stepsizeC', 1/2, ...
      'actor', @AgentNaturalActorCritic, ...
      'critic', @LSPELambda, ...
      'theta0', 'h50', ...
      'w0', [], ...
      'gamma', 0.9, ...
      'lambda', 1/2, ...
      'betaC', 0.1, ...
      'I', 1, ...
      'thetaC', Inf );
    
    % no parameter ranges by default
    paramRanges = struct();
    
  end
  
  
  methods
    
    function expr = run( this )
      
      expr = Experiment();
      expr.trainFunc = @trainTetris;
      expr.firstSeed = 1;
      expr.repeats = 4;
      expr.params = this.params;
      expr.paramRanges = this.paramRanges;
      
      run( expr );
      
    end
    
  end
  
end
