classdef Test < PersistentSingleton
  %TEST A single test case
  %
  %   The abstract base class for all test cases. The inheriting class
  %   should implement the methods Test.run() and Test.compare(). See
  %   documentation of these methods below for details.
  %
  %   Once a new class has been derived from Test, a persistent singleton
  %   instance of it has to be created and the name of the class should be
  %   added to the Test.AllTests list. The instance can be created as follows:
  %     PersistentSingleton.Init( <classname> )
  %   The class name must be added manually to Test.tests.
  %
  %   Note that changes to test parameters do not necesassarily have an
  %   effect, because the parameters are stored in the persistent singleton
  %   objects. Re-initializing these with Test.Rehash() or
  %   Tests.RehashAll() solves this problem.
  %
  %   See also Test, PersistentSingleton
  
  
  properties (Constant)
    
    % Critical property fields with accumulated data that should not be
    % overwritten in Rehash.
    ProtectedProperties = { 'results', 'errorMatrix', 'errorMatrixLabels', 'ProtectedProperties' };
    
  end
    
  properties
    
    % Previous results
    %   (map: (int32) revision -> result)
    results = containers.Map( 'KeyType', 'int32', 'ValueType', 'any' );
    
    % The differences between all tested revisions. This is computed in
    % Test.computeErrorMatrix(). errorMatrix(i,j) contains the error
    % between the i'th and j'th revisions. See Test.compareResults() for
    % the meaning of the error values.
    %
    % Note that revision numbers do not need to run contiguously. For
    % example, if the results map contains results only for revisions 3 and
    % 7, then these revisions will translate to indices 1 and 2 here,
    % respectively. The effective translation is stored in
    % errorMatrixLabels. For the previous example, errorMatrixLabels(1) ==
    % 3 and errorMatrixLabels(2) == 7.
    %
    %   (lower diagonal double matrix), (int32 array)
    errorMatrix; errorMatrixLabels;
    
  end
  
  
  methods (Abstract)
    
    % Runs the test and produces a result object.
    %
    %   result = run( this )
    %
    %   result
    %     A result object of any type that the method Test.compareResults
    %     accepts. The object is stored to the reference results map with
    %     'revision' as the key. A complete failure of the test can be
    %     indicated by, e.g., returning NaN and treating NaNs appropriately
    %     in the implementation of compareResults().
    result = run( this );
    
  end
  
  
  methods (Static)
    
    function object = Run( classname, revision, rerun, doSave )
      % Run the test.
      %
      %   object = Run( classname, revision, rerun, doSave )
      %
      % The test results will be associated with the provided revision
      % number. If results already exist for the given revision then the
      % test will be skipped by default, or rerun if the rerun argument is
      % set to true. All statistics based on the result are recomputed even
      % when the test is not rerun. A copy of the test object will be
      % returned. The results will be stored to the persistent singleton
      % instance of this class if doSave = true.
      
      object = PersistentSingleton.Load(classname);
      assert( isa( object, 'Test' ), 'The classname argument should refer to a Test class!' );
      
      % run if the result does not exist or if a rerun was requested
      if ~isKey( object.results, revision ) || rerun

        fprintf('run test..\n');
        
        % run the test and store the result
        object.results(revision) = run( object );
        
      else
        fprintf('skip (already run)\n');
      end

      % update the error matrix
      object = computeErrorMatrix( object );

      if doSave; PersistentSingleton.Save(classname, object); end
      
    end
    
    function Rehash( classname )
    % Re-initialize the specified test case class object without losing
    % stored persistent data.
      
      % load the current persistent instance
      test = Test.Load( classname );
      
      % create a fresh instance of the class
      test_new = eval( classname );
      
      % copy over all "non-protected" properties
      props = setdiff( properties( test_new ), Test.ProtectedProperties );
      if ~isempty(props)
        for prop=props
          test.(prop{1}) = test_new.(prop{1});
        end
      end
      
      % store back
      Test.Save( classname, test );
      
    end
    
    
    % utility methods begin
    
    
    function error = CompareTrainerResults( lhsSurface, rhsSurface, lhsArray, rhsArray )
      % Compare two Trainer object arrays and some pre-extracted surface
      % level of them. Deep comparison is based on all returns, conds and
      % all values in agent logs. See also Test.compareResults().
      
      % compute surface-level error
      errorS = recursiveDiff( lhsSurface, rhsSurface );
      
      % compute full-depth error
      errorD = recursiveDiff( lhsArray, rhsArray, {'rstream'} );
      
      % decide overall error
      if isinf(errorS)
        % infinite or structural mismatch on surface level
        error = Inf;
      elseif errorS > 0
        % surface-level finite mismatch:
        % return the surface-level error + 2*eps (add 2*eps to avoid possible aliasing with the following case)
        error = errorS + 2*eps;
      elseif errorS == 0 && errorD > 0
        % surface-level match, full-depth mismatch
        error = eps;
      elseif errorS == 0 && errorD == 0
        % complete match
        error = 0;
      else
        assert(false);   % should not be reached
      end
      
    end
    
  end
  
  
  methods
    
    function error = compareResults( this, lhs, rhs, fieldname )
    % Compare two result objects. The default implementation assumes
    % Experiment objects. Re-implement in case of other data types. Surface
    % comparison is based on training iteration returns by default. This
    % can be changed via the 'fieldname' argument. Deep comparison is based
    % on all data.
    %
    %   lhs, rhs
    %     The results to be compared. rhs corresponds always to the later
    %     revision.
    %
    %   (double) error
    %     The difference between lhs and rhs. Zero means that they are
    %     exactly equal. Eps means that they are exactly equal on surface
    %     level (e.g., when looking at the returns during training
    %     iterations) but differ on deeper levels, including infinite or
    %     structural differences at some deeper level. Finite positive
    %     values above eps indicate a difference also on the surface level
    %     and the value itself encodes the amount of that difference. Inf
    %     signals infinite or structural mismatch on the surface level.
      
      % handle args
      if ~exist( 'fieldname', 'var' ); fieldname = 'returnsTrain'; end
      
      % forward the call to CompareTrainerResults() after extracting the
      % surface level
      error = Test.CompareTrainerResults( ...
        getResults( lhs, fieldname, repmat({'m'}, 1, length(lhs.paramNames)) ), ...
        getResults( rhs, fieldname, repmat({'m'}, 1, length(rhs.paramNames)) ), ...
        [lhs.results.trainer], [rhs.results.trainer] );
      
    end
    
  end
  
  
  % private methods begin
  
  
  methods (Access=private)
    
    function this = computeErrorMatrix( this )
      
      fprintf( 'Test: Computing error matrix..' );
      
      % enumerate all revisions that have stored results and store them
      revisions = cell2mat( keys(this.results) );
      this.errorMatrixLabels = revisions;
       
      % reset the errorMatrix
      this.errorMatrix = nan( length(revisions) );
      
      % loop through all revision pairs that have stored results
      for i=1:length(revisions)
        for j=1:i-1
          
          % compare and store (later revision must become rhs!)
          this.errorMatrix(i,j) = compareResults( this, this.results(revisions(j)), this.results(revisions(i)) );
          
        end
      end
      
      fprintf( ' done\n' );
      
    end
    
  end
  
end
