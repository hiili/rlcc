classdef TetrisStandardFeatures < Tetris
  %TETRISSTANDARDFEATURES Tetris environment with standard featurization.
  %
  %   The Tetris environment with the standard features defined by
  %   Bertsekas & Tsitsiklis (1996).
  %
  %   Note that this Matlab implementation does not produce the same
  %   results as the mex implementation.
  %
  %   The 'number of holes' feature: The possible literal interpretations
  %   of Bertsekas & Tsitsiklis' definition of a hole is probably not what
  %   was meant (holes: "number of empty positions of the wall that are
  %   surrounded by full positions"). We use the intuitively more appealing
  %   definition from Thiery & Scherrer (2010): "A hole is an empty cell
  %   covered by a full cell," with the interpretation that the covering
  %   full cell can be at any distance above the empty cell but on the same
  %   column.
  %
  %
  %   References
  %
  %     Bertsekas & Tsitsiklis (1996). Neuro-dynamic programming.
  %     Thiery & Scherrer (2010). Building controllers for Tetris.

  % NOTE: Actions leading to termination are handled differently here than
  % in the mex implementation. TODO: add an explicit "will terminate"
  % feature to action features and use it in action selection.
  %
  % NOTE: This Matlab implementation (vs. mex) is not well tested in its
  % current state.
  
  properties (Access=private)
    
    IMMREWFEATURE = true;
    NOBIAS = false;
    
    % environment properties
    props;
    
    % dimension of the standard feature set for the current board size
    stdFeatureDim;
    
  end
  
  methods
    
    function this = TetrisStandardFeatures( rows, columns, varargin )
      % Constructor. Arguments are as in Tetris constructor.
      
      this = this@Tetris( rows, columns, varargin{:} );
      
      % compute standard feature set dimension
      this.stdFeatureDim = 2 * this.columns + 2;
      
      % set observation props
      this.props.observationType = 'c';
      this.props.observationDim = this.stdFeatureDim;
      
      % set action props
      this.props.useActionsList = true;
      this.props.actionTypes = 'c';
      this.props.actionDim = this.stdFeatureDim;
      if this.IMMREWFEATURE, this.props.actionDim = this.props.actionDim + 1; end
      if this.NOBIAS, this.props.actionDim = this.props.actionDim - 1; end
      
    end
    
    % return the environment properties struct
    function props = getProps( this ); props = this.props; end
    
  end
  
  
  
  
  % protected methods begin (implementations of abstract methods)
  
  
  
  
  methods (Access=protected)
    
    function actions = getAvailableActions( this )
      % Returns a matrix that contains the feature vectors for all
      % available actions: actions(i,:) contains the feature vector for the
      % i'th available action.
      
      % get available raw action vectors
      rawActions = getAvailableActions@Tetris( this );
      
      % initialize the action matrix
      actions = zeros( size(rawActions,1), this.props.actionDim );

      % featurize the actions
      for a=1:size(rawActions,1)

        % lookahead: obtain features of the resulting state
        board = this.board; 
        [this, reward] = dropPiece( this, rawActions(a,:) );
        observation = generateObservation( this );
        this.board = board;

        % add features to the actions matrix
        if ~isempty(observation)
          if this.NOBIAS; observation(end) = []; end
          if this.IMMREWFEATURE; observation(end+1) = reward; end                                          %#ok<AGROW>
          actions(a,:) = observation;
        end

      end
        
    end
    
    function observation = generateObservation( this )
      % Generate the row feature representation for the current state
      
      % episode ended?
      if isempty(this.board); observation = []; return; end
      
      % add column heights (first features)
      observation = zeros(1, this.columns);
      for row=this.rows:-1:1   % sweep upwards
        observation(logical(this.board(row,:))) = this.rows - row + 1;
      end
      
      % add absolute height differences
      observation = [ observation, abs(diff(observation)) ];
      
      % add maximum column height
      observation(end+1) = max(observation(1:this.columns));
      
      % add number of holes: HD_COVEREDBY: take a downwards-shifted copy of
      % the board and AND it with a negated copy of the board
      %observation(end+1) = sum(sum( logical(this.board(1:end-1,:)) & ~logical(this.board(2:end,:)) ));
      
      % add number of holes: HD_UNDERTOPLINE: count empty cells, then
      % substract the area above the walltop
      observation(end+1) = sum( sum( ~logical(this.board) ) - (this.rows - observation(1:this.columns)) );
      
      % add the constant feature
      observation(end+1) = 1;
      
    end
    
  end
  
end
