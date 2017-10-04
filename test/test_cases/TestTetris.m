classdef TestTetris < Test
  %TETRIS Basic test case for the Tetris environment using the random agent
  
  
  methods
    
    function result = run( this )
      
      result = trainTetris( ...
        'seed', 1, ...
        'conf', 'test_Tetris_stdfeats', ...
        'useMex', false, ...
        'iterations', 10, ...
        'testEpisodes', 10, ...
        'episodesIt', 10, ...
        'iterationsCIt', 1 );
      
    end
    
    % Compare the results, which are result structs from Train in this
    % case. The comparison result is binary: for equal lhs and rhs, error
    % is 0, and for nonequal lhs and rhs, error is Inf.
    function error = compareResults( this, lhs, rhs )
      
      error = recursiveDiff( lhs, rhs, {'rstream'} );
      
    end
    
  end
  
end
