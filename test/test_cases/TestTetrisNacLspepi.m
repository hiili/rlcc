classdef TestTetrisNacLspepi < TestTetrisNac
  %TESTTETRISNACLSPEPI Test case for NAC and LSPI-style LSPE in the Tetris environment
  %
  % Reaches a 50->30k points improvements in one iteration.
  
  
  methods
    
    function this = TestTetrisNacLspepi()
      
      this.params.critic = @LSPELambda;
      
      this.params.iterations = 1;
      this.params.episodesIt = 2000;
      this.params.testEpisodes = 50;
      this.params.iterationsCIt = 10;
      this.params.lambda = 0.95;
      this.params.gamma = 0.999;
      
      this.params.stepsizeA = 10;
      this.params.stepsizeC = 1;
      
    end
    
    function error = compareResults( this, lhs, rhs, fieldname )
      error = compareResults@TestTetrisNac( this, lhs, rhs, 'returnsTest' );
    end
    
  end
  
end
