classdef TestTetrisNacFullTD < TestTetrisNac
  %TESTTETRISNACFULLTD Basic test case for NAC and FullTD in the Tetris environment
  
  
  methods
    
    function this = TestTetrisNacFullTD()
      
      this.params.iterations = 3;
      this.params.critic = @FullTDLambda;
      this.params.logLevel = 'iterations';
      this.paramRanges.criticBatchMethod = {'TD(0)', 'MC', 'LSTD', 'LSTD(0)'};
      
    end
    
  end
  
end
