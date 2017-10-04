classdef TestTetrisStopConds1 < TestTetrisNac
  %TESTTETRISSTOPCONDS1 Basic test case for stopping conditions using the Tetris environment
  
  
  methods
    
    function this = TestTetrisStopConds1()
      
      this.params.critic = @LSPELambda;
      
      this.params.stopConds = struct( ...
        'train', struct( 'maxSteps', 200, 'totalRewardRange', [-Inf, 76] ), ...
        'test', struct( 'maxSteps', 100000, 'totalRewardRange', [-Inf, Inf] ) );
      
    end
    
  end
  
end
