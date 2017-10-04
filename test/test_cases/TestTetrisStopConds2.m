classdef TestTetrisStopConds2 < TestTetrisNac
  %TESTTETRISSTOPCONDS2 Basic test case for stopping conditions using the Tetris environment
  
  
  methods
    
    function this = TestTetrisStopConds2()
      
      this.params.critic = @LSPELambda;
      
      this.params.trainMaxSteps = 200;
      this.params.trainMaxReturn = 76;
      
    end
    
  end
  
end
