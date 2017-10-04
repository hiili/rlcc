classdef TestTetrisNacLspeAvoidTerm < TestTetrisNac
  %TESTTETRISNACLSPEAVOIDTERM Basic test case for NAC and LSPE in the
  %Tetris environment with termination avoidance
  
  
  methods
    
    function this = TestTetrisNacLspeAvoidTerm()
      
      this.params.critic = @LSPELambda;
      this.params.theta0 = 'h20b';
      
    end
    
  end
  
end
