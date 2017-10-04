classdef TestTetrisCnacLspe < TestTetrisNac
  %TESTTETRISCNACLSPE Basic test case for CNAC and LSPE in the Tetris environment
  
  
  methods
    
    function this = TestTetrisCnacLspe()
      
      this.params.critic = @LSPELambda;
      
      this.params.episodesIt = 50;
      this.params.iterationsCIt = 5;
      
      this.params.stepsizeA = 1e10;
      this.params.thetaC = 50;
      
    end
    
  end
  
end
