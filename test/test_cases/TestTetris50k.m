classdef TestTetris50k < TestTetrisNac
  %TESTTETRIS50K Test case for the 50k points in one iteration result
  
  
  methods
    
    function this = TestTetris50k()
      
      this.params.critic = @LSPELambda;
      
      this.params.theta0 = 'h500';
      
      this.params.episodesIt = 500;
      this.params.iterationsCIt = 10;
      this.params.iterations = 2;
      this.params.testEpisodes = 25;
      
      this.params.critic = @LSPELambda;
      this.params.lambda = 1;
      this.params.gamma = 0.99;
      this.params.I = 0;
      
      this.params.stepsizeA = 20;
      this.params.stepsizeC = 0.5;
      this.params.trainMaxSteps = 2000;
      
    end
    
    function error = compareResults( this, lhs, rhs )
      error = compareResults@Test( this, lhs, rhs, 'returnsTest' );
    end
    
  end
  
end
