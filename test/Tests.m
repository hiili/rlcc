classdef Tests < PersistentSingleton
  %TESTS Manage a set of test cases
  %
  %   The main class for managing and running test cases. The testing
  %   framework allows matching results obtained with new revisions against
  %   results from all earlier revisions. Both exact and approximate
  %   (stochastic) matching is supported.
  %
  %   The testing framework is based on persistent singleton instances of
  %   the Tests class and the test case classes derived from Test. All
  %   functionality is accessed via static methods of these classes.
  %   Storage directory is defined in the PersistentSingleton class.
  %
  %   Existing test cases can be run all at once with the static method
  %   Tests.Run(). See Test for instructions on creating new test cases.
  %   Reference revisions for individual tests are set in the struct
  %   Tests.AllTests below. Individual tests can be run by providing
  %   a 'testname' argument to Tests.Run().
  %
  %   Test results can be compared using the static method Tests.Diff().
  %   The persistent Tests instance can be loaded with Tests.Load(). The
  %   persistent instance of test <classname> can be loaded with Test.Load(
  %   <classname> ).
  %
  %   Note that it seems that Matlab produces slightly differing results
  %   when the experiments are run in parallel mode (vs. sequential). All
  %   reference results are produced in parallel mode.
  %
  %   See also Test, PersistentSingleton
  
  
  properties (Constant)
    
    % A struct array that lists all existing test cases. It is allowed to
    % change the order of the tests (all data is completely re-read from
    % the test cases on each run).
    %
    % Fields:
    %   (string) classname
    %     Name of the class of the test case
    %   (int32) referenceRevision
    %     The revision against which all new results should be compared
    %     when deciding whether the test case passes or fails. The default
    %     zero value indicates that no reference revision has been set.
    %   (logical) active
    %     Whether the test case is active (true) or inactive (false)
    AllTests = [ ...
      struct( 'classname', 'TestTest', 'referenceRevision', 1, 'active', false ), ...
      struct( 'classname', 'TestTetris', 'referenceRevision', 458, 'active', true ), ...
      struct( 'classname', 'TestTetrisTestingPhases', 'referenceRevision', 458, 'active', true ), ...
      struct( 'classname', 'TestTetrisStopConds1', 'referenceRevision', 458, 'active', true ), ...
      struct( 'classname', 'TestTetrisStopConds2', 'referenceRevision', 458, 'active', true ), ...
      struct( 'classname', 'TestTetrisNacLstd', 'referenceRevision', 458, 'active', true ), ...
      struct( 'classname', 'TestTetrisNacLspe', 'referenceRevision', 458, 'active', true ), ...
      struct( 'classname', 'TestTetrisNacLspepi', 'referenceRevision', 458, 'active', true ), ...
      struct( 'classname', 'TestTetrisNacLspeAvoidTerm', 'referenceRevision', 269, 'active', false ), ...
      struct( 'classname', 'TestTetrisCnacLspe', 'referenceRevision', 458, 'active', true ), ...
      struct( 'classname', 'TestTetrisNacFullTD', 'referenceRevision', 458, 'active', true ), ...
      struct( 'classname', 'TestTetris50k', 'referenceRevision', 458, 'active', true ), ...
      struct( 'classname', 'TestGraphRotorbladeNac', 'referenceRevision', 458, 'active', true ), ...
      struct( 'classname', 'TestGraphHiddenForkOPI', 'referenceRevision', 458, 'active', true ), ...
      struct( 'classname', 'TestGridNac', 'referenceRevision', 458, 'active', true ), ...
      struct( 'classname', 'TestGraphSynthetic', 'referenceRevision', 458, 'active', true ), ...
      struct( 'classname', 'TestFeaturizerSynthetic', 'referenceRevision', 458, 'active', true ), ...
      ];
    
  end
  
  
  properties
    
    % Copies of the error matrices for all active tests. errorMatrices{i}
    % contains a copy of the error matrix of the i'th test (counting
    % includes also inactive tests). Note that the matrices are maintained
    % also in the test case objects; a copy is maintained here only for
    % convenience.
    %   (cell array of lower diagonal double matrices), (cell array of int32 arrays)
    errorMatrices, errorMatricesLabels;
    
  end
  
  
  methods (Static)
    
    function [tests, testArray] = Run( varargin )
      % Run all active tests.
      %
      %   [tests, testArray] = Run( revision, <name/value pairs> ... )
      %
      % A summary is printed and the results are stored to the persistent
      % singleton instances of this class and the Test classes. Possibly
      % existing results for the same revision will be replaced with a
      % rerun only if the 'rerun' flag is set to true. All statistics based
      % on the results are always recomputed, however, even if no rerun has
      % taken place. New information will be stored permanently only if the
      % 'save' flag is set to true. The updated objects are always returned
      % by the method, which is useful when the 'save' flag is set to
      % false.
      %
      %   (int32) revision
      %     The revision number that the result should be stored and
      %     associated with.
      %
      %   'testname', (string) classname
      %     Name of the test to be run. Default: [] (run all tests)
      %
      %   'rerun', (logical) rerun
      %     Possibly existing results for the same revision will be replaced
      %     with a rerun only if this is set to true. Default: false
      %
      %   'save', (logical) flag
      %     The results will be saved to persistent storage. Default: false
      %
      %   (Tests) tests
      %     A copy of the final Tests object.
      %
      %   (cell array of Test objects) testArray
      %     Copies of the final Test objects.
      
      args = inputParser;
      args.addRequired( 'revision', @isnumeric );
      args.addParamValue( 'testname', [], @(x) (ischar(x) || isempty(x)) );
      args.addParamValue( 'rerun', false, @islogical );
      args.addParamValue( 'save', false, @islogical );
      args.parse( varargin{:} );
      
      revision = args.Results.revision;
      testname = args.Results.testname;
      rerun = args.Results.rerun;
      doSave = args.Results.save;
      
      % transfer execution to the instance object
      tests = Tests.Load();
      [tests, testArray] = run( tests, revision, testname, rerun, doSave );
      if doSave; Tests.Save( tests ); end
      
    end
    
    function RehashAll()
      % Re-initialize all test case class objects without losing stored
      % persistent data.
      
      for test=Tests.AllTests
        fprintf('.');
        Test.Rehash( test.classname );
      end
      fprintf('\n');
      
    end
    
    function d = DiffFailed( varargin )
      % Diff results of all failed active tests.
      %
      %   DiffFailed( ... )
      %
      % This static method uses recursiveDiff() to produce a verbose diff
      % for all failed tests. The diff is between the latest result and the
      % reference result, i.e., it shows the differences that caused the
      % test to fail.
      %
      %   ...
      %     All arguments are passed directly to recursiveDiff()
      %     (after the lhs and rhs arguments).
      %
      % Examples
      %
      %   DiffFailed( {'StreamID, 'props'}, 'diff+silentskip' )
      %     Ignore StreamID and props fields, quietly skip already compared
      %     handle pairs.
      
      % load the singleton instance
      this = Tests.Load();
      
      % loop through all tests
      for t=1:length(Tests.AllTests)
        
        % skip if inactive
        if ~Tests.AllTests(t).active; continue; end
        
        % find error matrix indices for the comparison between the latest
        % and the reference revision
        latestResultInd = length( this.errorMatricesLabels{t} );
        referenceResultInd = find( this.errorMatricesLabels{t} == Tests.AllTests(t).referenceRevision );
        
        % skip if the test passes
        if isempty(referenceResultInd) || latestResultInd == referenceResultInd || ...
            this.errorMatrices{t}(latestResultInd, referenceResultInd) == 0; continue; end
        
        % test fails, diff it
        Tests.Diff( Tests.AllTests(t).classname, ...
          this.errorMatricesLabels{t}(referenceResultInd), this.errorMatricesLabels{t}(latestResultInd), varargin{:} );
        fprintf('\n\n');
  
      end
      
    end
    
    function d = Diff( test, rev1, rev2, varargin )
      % Diff test results from different revisions.
      %
      %   d = Diff( test, [rev1, [rev2, ...]] )
      %
      % This static method uses recursiveDiff() to produce a verbose diff
      % of two test results.
      %
      %   (Test | string) test
      %     Defines the test to be used. Either a Test object or a test
      %     name can be provided.
      %
      %   (int) rev1, rev2
      %     Revisions to compare. Either one can be omitted or set to an
      %     empty matrix, in which case rev1 defaults to the reference
      %     revision and rev2 defaults to the most recent revision. Either
      %     or both can be also strings containing the 'end' keyword, in
      %     which case the revision is expanded with the expression:
      %       revN = revisions( revN )
      %     For example, rev1 = 'end-1' defines the second-to-last
      %     revision.
      %
      %   ...
      %     Any additional arguments are passed directly to recursiveDiff()
      %     (after the lhs and rhs arguments).
      %
      %   d
      %     The return value of recursiveDiff().
      %
      % See also recursiveDiff
      
      % load the test if a test name was provided
      if ischar(test); test = Test.Load( test ); end
      
      % choose revisions
      if ~exist('rev1', 'var') || isempty(rev1)
        tmp = Tests.AllTests;
        rev1 = tmp(strcmp( {tmp.classname}, class(test) )).referenceRevision;
      end
      if ~exist('rev2', 'var') || isempty(rev2); keys = test.results.keys; rev2 = keys{end}; end
      
      % compare data
      keys = test.results.keys;                                                                              %#ok<NASGU>
      if ischar(rev1); rev1 = eval([ 'keys{' rev1 '}' ]); end
      if ischar(rev2); rev2 = eval([ 'keys{' rev2 '}' ]); end
      fprintf( 'Comparing revisions %d and %d of test %s:\n\n', rev1, rev2, class(test) );
      if nargout
        d = recursiveDiff( test.results(rev1), test.results(rev2), varargin{:} );
      else
        recursiveDiff( test.results(rev1), test.results(rev2), varargin{:} );
      end
      
    end
    
    function Init(varargin); PersistentSingleton.Init( mfilename('class'), varargin{:} ); end
    function object = Load(varargin); object = PersistentSingleton.Load( mfilename('class'), varargin{:} ); end
    function Save(varargin); PersistentSingleton.Save( mfilename('class'), varargin{:} ); end
    
  end
  
  
  % private methods begin
  
  
  methods (Access=private)
    
    function [this, testArray] = run( this, revision, testname, rerun, doSave )
      
      % select test cases: all if testname = []
      if isempty(testname)
        
        % select all tests
        selectedTests = 1:length(Tests.AllTests);
        
        % reset our result cache
        this.errorMatrices = repmat({[]}, 1, length(Tests.AllTests));
        this.errorMatricesLabels = repmat({[]}, 1, length(Tests.AllTests));
        
      else
        
        % select the indicated test
        tmp = Tests.AllTests;   % Matlab currently requires this intermediate step
        selectedTests = find(strcmp( testname, {tmp.classname} ));
        
      end
      
      % loop through selected test cases
      if isempty(selectedTests); fprintf( 'Warning: no tests to run!\n' ); end
      testArray = repmat({[]}, 1, length(Tests.AllTests));
      for i=selectedTests
        
        % skip inactive tests (but still load and return them and synchronize errorMatrices and errorMatricesLabels)
        if ~Tests.AllTests(i).active;
          testArray{i} = Test.Load( Tests.AllTests(i).classname );
          this.errorMatrices{i} = testArray{i}.errorMatrix;
          this.errorMatricesLabels{i} = testArray{i}.errorMatrixLabels;
          continue;
        end
        
        % print header
        fprintf('%s\n%s\n', Tests.AllTests(i).classname, repmat( '-', 1, length(Tests.AllTests(i).classname) ) );
        
        % run test
        testArray{i} = Test.Run( Tests.AllTests(i).classname, revision, rerun, doSave );
        
        % store a copy of the error matrix and labels
        this.errorMatrices{i} = testArray{i}.errorMatrix;
        this.errorMatricesLabels{i} = testArray{i}.errorMatrixLabels;
        
        % find error matrix indices for the comparison between the current
        % and the reference revision
        currentResultInd = find( testArray{i}.errorMatrixLabels == revision );
        referenceResultInd = find( testArray{i}.errorMatrixLabels == Tests.AllTests(i).referenceRevision );

        % print a summary
        if isempty(referenceResultInd)
          fprintf('PASS (reference revision not set or does not exist)\n');
        elseif currentResultInd == referenceResultInd
          fprintf('PASS (reference revision and current revision are the same)\n');
        else
          
          % check the error
          if testArray{i}.errorMatrix(currentResultInd, referenceResultInd) == 0
            fprintf('PASS');
          elseif testArray{i}.errorMatrix(currentResultInd, referenceResultInd) == eps
            fprintf('PARTIAL PASS');
          else
            fprintf('FAIL');
          end
          
          % print the error (print eps as 'eps (...)')
          error = testArray{i}.errorMatrix(currentResultInd, referenceResultInd);
          if error ~= eps; errorStr = num2str( error, '%g' );
          else errorStr = 'eps (results differ only on deeper levels)'; end
          fprintf(': reference revision = %d, error = %s\n', Tests.AllTests(i).referenceRevision, errorStr );
          
        end
        
        fprintf('\n');
        
      end
      
    end
    
  end
  
end
