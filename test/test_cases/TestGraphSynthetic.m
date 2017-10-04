classdef TestGraphSynthetic < Test
  %TESTGRAPHSYNTHETIC Test the synthetic graph class.
  %
  %   Tests the general operation of GraphSynthetic.
  
  
  properties
    
    % parameters
    params = struct( ...
      'environment', [], ...
      'agent', 'NAC', ...
      'iterations', 10, ...
      'episodesIt', 50, ...
      'trainMaxSteps', 100, ...
      'stepsizeA', 1, ...
      'actor', @AgentNaturalActorCritic, ...
      'critic', @LSPELambda, ...
      'lambda', 0.5 );
    
    % parameter ranges
    paramRanges = struct();   % filled in constructor
    
  end
  
  methods
    
    function this = TestGraphSynthetic()
      
      for i=1:4
        this.paramRanges.environment{i} = GraphSynthetic( ...
          'synthSeed', i, ...
          'sCount', 3^i, ...   % 3..81
          'aCount', 5 - i, ...   % 4..1
          'dimsMdp', i, ...
          'dimsPomdp', ceil(i/1.5), ...
          'PSynthMean', i/4, ...
          'PSynthVariance', i/2, ...
          'OSynthVariance', (i-1) / 4 + eps );
        this.paramRanges.environment{i}.construct();
      end
      
    end
    
    function expr = run( this )
      
      expr = Experiment();
      expr.trainFunc = @train;
      expr.firstSeed = 1;
      expr.repeats = 1;
      expr.params = this.params;
      expr.paramRanges = this.paramRanges;
      
      run( expr );
      
    end
    
  end
  
end

