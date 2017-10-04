classdef TestTetrisTestingPhases < TestTetrisNac
  %TESTTETRISTESTINGPHASES Basic test case for 'trainingTest' and 'testing' phases
  
  
  methods
    
    function this = TestTetrisTestingPhases()
      
      this.params.iterations = 3;
      this.params.episodesIt = 10;
      this.params.trainTestEpisodes = 5;
      this.params.testEpisodes = 10;
      
    end
    
    
    function data = run( this )
      
      expr1 = Experiment();
      expr1.trainFunc = @trainTetris;
      expr1.firstSeed = 1;
      expr1.repeats = 4;
      expr1.params = this.params;
      expr1.paramRanges = this.paramRanges;
      
      expr2 = expr1.clone();
      expr2.params.trainTestEpisodes = 0;
      expr2.params.testEpisodes = 0;
      
      expr1.run();
      expr2.run();
      
      data = {expr1, expr2};
      
    end
    
    
    function error = compareResults( this, lhs, rhs, ~ )
      
      % compare expr1 against the reference revision of expr1, field by field
      errorRef = [];
      for fn={'returnsTrain', 'returnsTrainTest', 'returnsTest'}
        errorRef(end+1) = compareResults@Test( this, lhs{1}, rhs{1}, fn{1} );                                %#ok<AGROW>
      end
      errorRef = max(errorRef);
      
      % make sure that testing phases do not affect learning, expect eps
      % error and thus substract eps
      errorThis = compareResults@Test( this, rhs{1}, rhs{2}, 'returnsTrain' ) - eps;
      
      error = max([errorRef errorThis]);
      
    end
    
  end
  
end
