classdef TestTetrisNacLspe < TestTetrisNac
  %TESTTETRISNACLSPE Basic test case for NAC and LSPE in the Tetris environment
  
  
  methods
    
    function this = TestTetrisNacLspe()
      
      this.params.critic = @LSPELambda;
      
    end
    
  end
  
end
