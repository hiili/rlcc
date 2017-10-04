classdef TestTest < Test
  %TESTTEST A test case for testing the test system itself
  %
  %   Uses and manipulates a snapshot of a Tetris test run so as to test
  %   the testing system itself.
  %
  %   The run() method should be modified manually to simulate the effect
  %   of changes between revisions. Revision 1 should be set as the
  %   reference result. Running the test:
  %
  %     (set revision = 1 below); Tests.Run( 1, 'testname', 'TestTest', 'save', true )
  %     (set revision = 2 below); Tests.Run( 2, 'testname', 'TestTest', 'save', true )
  %     ...
  %     (set revision = 9 below); Tests.Run( 9, 'testname', 'TestTest', 'save', true )
  %     (set revision = 10 below); Tests.Run( <anything above 9>, 'testname', 'TestTest', 'save', false )
  %                                                                                               """""
  %   The test will generate failures during this process, which is normal.
  %   Actual success or failure is reported at the last line above, i.e.,
  %   when the revision variable below is set to 10 and the revision in
  %   Tests.Run is greater than 9.
  %
  %   You might want to disable this test from Tests.AllTests after
  %   checking once and re-enable it only when manually re-running it.
  
  
  methods
    
    function result = run( this )
      %#ok<*NODEF>
      
      % load the 'result' variable and the reference error matrix
      load('TestTest_data.mat');   % depends on Matlab looking through the search path
      
      revision = 10;   % change this between runs
      switch revision
        case 1
          % no-op: reference
        case 2
          % no-op: produce an exact match
        case 3
          % make a finite deep level modification
          result.results(1).trainer.results.returnsTrainEpisodes(1) = ...
            result.results(1).trainer.results.returnsTrainEpisodes(1) + 100;
        case 4
          % make an infinite deep level modification
          result.results(1).trainer.results.returnsTrainEpisodes(1) = Inf;
        case 5
          % make a structural deep level modification
          result.results(1).trainer.results.returnsTrainEpisodes(1) = [];
        case 6
          % make a finite surface level modification
          result.returnsTrain(1,1) = result.returnsTrain(1,1) + 100;
        case 7
          % make a finite surface level modification and a structural deep
          % level modification
          result.returnsTrain(1,1) = result.returnsTrain(1,1) + 100;
          result.results(1).trainer.results.returnsTrainEpisodes(1) = [];
        case 8
          % make an infinite surface level modification
          result.returnsTrain(1,1) = Inf;
        case 9
          % make a structural surface level modification
          result.returnsTrain(:,1) = [];
          
          % (not all possible combinations are covered)
          
        case 10
          
          if isequalwithequalnans( this.errorMatrix, errorMatrix )
            fprintf('Error matrix matches the reference error matrix.\n');
          else
            fprintf('Error matrix DOES NOT match the reference error matrix!\n');
            result.returnsTrain = 0;   % change the result so as to signal an error
          end
          
      end
      
    end
    
  end
  
end
