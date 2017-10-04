classdef TestTetrisNacLstd < TestTetrisNac
  %TESTTETRISNACLSTD Basic test case for NAC and LSTD in the Tetris environment
  
  
  methods
    
    function this = TestTetrisNacLstd()
      
      this.params.critic = @LSTDLambda;
      
    end
    
  end
  
end
