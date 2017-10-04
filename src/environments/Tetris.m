classdef Tetris < Environment
  %TETRIS An implementation of the Tetris benchmark.
  %
  %   The Tetris environment, as in Bertsekas & Tsitsiklis (1996).
  %
  %   Observation space
  %     rows x columns + 1 -dimensional integer, ranges: [0,1] for the
  %     first rows x columns dimensions, [1,7] for the last dimension.
  %     observation(1) = state of the cell at row 1, column 1 (0=free),
  %     observation(2) = state of the cell at row 1, column 2,
  %     ...
  %     observation(end) = index of the currently falling piece.
  %
  %   Action space
  %     2-dimensional integer with varying ranges.
  %       action(1) = piece orientation (range between [1,1] and [1,4])
  %       action(2) = piece position (1 = leftmost possible)
  %
  %   Reward
  %     +1 for every cleared row, 0 otherwise.
  %
  %   Start distribution
  %     Empty board with a uniformly random falling piece.
  %
  %   Terminal conditions
  %     An episode ends after the agent places a piece in such a way that
  %     the piece would extend beyond the top of the board (checked before
  %     clearing possibly filled rows).
  %
  %   Dynamics
  %     The falling piece is placed according to the position and
  %     orientation specified by the agent. All filled rows are removed and
  %     the rows above them are moved downwards.
  %
  %
  %   References
  %
  %     Bertsekas & Tsitsiklis (1996). Neuro-dynamic programming.
  
  % NOTE The Matlab implementation (vs. mex) is not well tested in its
  % current state.

  
  properties (Access=protected)
    
    % size of the board
    rows, columns;
    
    % visualization delay. -1 = visualization off, 0 = wait for keypress,
    % >0 = wait for the specified number of seconds.
    visualization;
    
    
    % board state: 0 means empty, positive integers mean filled and the
    % integer value defines the color index for the cell. board(1,1) is the
    % top left corner, and board(row,col) is the cell at (row,col). board =
    % [] means either that newEpisode() has not been called yet for the
    % first time, or that the end condition has been met.
    %
    %   (rows x columns uint8 matrix) board
    board;
    
    % the currently falling piece. type: int, range: [1,7]
    fallingPiece;
    
    % action matrix
    actions;
    
    % number of rows cleared during the last step and during this episode.
    % type: int
    clearedRows, totalClearedRows;
    
    
    % All available pieces in all possible orientations.
    % Rotations are generated in the constructor.
    %
    %   (row cell array of row cell arrays of r x c uint8 matrices) pieces
    %     pieces{i,j}[row,col] defines the element at (row,col) in the i'th
    %     piece in its j'th possible orientation.
    pieces = ...
      { {uint8([1,1; ...
                1,1])}, ...
        {uint8([0,1,0; ...
                1,1,1])}, ...
        {uint8([1,1,1,1])}, ...
        {uint8([1,0,0; ...
                1,1,1])}, ...
        {uint8([0,0,1; ...
                1,1,1])}, ...
        {uint8([1,1,0; ...
                0,1,1])}, ...
        {uint8([0,1,1; ...
                1,1,0])}};
    
    % precomputed piece heightmaps for speedup
    pieceHeightmaps;
    
  end
  
  properties (Access=private)
    
    % environment properties
    props;
    
  end
  
  methods
    
    function this = Tetris( rows, columns, varargin )
      % Constructor
      %
      %   (int) rows, columns
      %     both must be at least 4
      %   ['visualize', (int) delay]
      %     Visualization is disabled if this argument is omitted or set to
      %     -1. 0 causes program execution to halt until a key is pressed.
      %     Otherwise 'delay' defines the number of seconds to wait between
      %     steps.
      
      % check and parse args
      args = inputParser;
      args.addRequired( 'rows', @(x) x >= 4 );
      args.addRequired( 'columns', @(x) x >= 4 );
      args.addParamValue( 'visualize', -1, @isnumeric );
      args.parse( rows, columns, varargin{:} );
      
      % assign args
      this.rows          = args.Results.rows;
      this.columns       = args.Results.columns;
      this.visualization = args.Results.visualize;
      
      
      % set props
      this.props.observationType = 'c';
      this.props.observationDim = this.rows * this.columns + 1;
      this.props.useActionsList = true;
      this.props.actionTypes = 'c';
      this.props.actionDim = 2;
      
      % generate piece orientations and heightmaps
      this = generatePieceOrientations( this );
      this = generatePieceHeightmaps( this );
      
    end
    
    % return the environment properties struct
    function props = getProps( this ); props = this.props; end
    
    
    function visualizeState( this, state )
      % draw a visualization of either the current state or of the provided
      % into the current figure
      
      % select and parse the state
      if nargin >= 2
        board = uint8( reshape(state(1:end-1), this.columns, this.rows)' );
        fallingPiece = state(end);
        totalClearedRows = NaN;
      else
        board = this.board; fallingPiece = this.fallingPiece; totalClearedRows = this.totalClearedRows;
      end
      
      clf; colormap([0 0 0; 0 0 1; 1 0.5 0; 1 0 0; 1 1 1; 1 0 1; 0 1 1; 0 1 0]);
      
      % draw the falling piece
      piece = fallingPiece * this.pieces{fallingPiece}{1};
      pieceImage = zeros(4, 6, 'uint8');
      pieceImage(2:size(piece,1)+1,2:size(piece,2)+1) = piece;
      subplot(2,2,2); image(pieceImage);
      axis image; title('currently falling piece'); xlabel(['score: ' num2str(totalClearedRows)]);
      
      % draw the board
      subplot(1,2,1); image(board);
      axis image; title('board configuration');
      
    end
    
  end
  
  
  % protected methods begin (implementations of abstract methods)
  
  
  methods (Access=protected)
    
    % Returns a matrix that contains all available actions: actions(i,:)
    % contains the i'th available action.
    function actions = getAvailableActions( this ); actions = this.actions; end
    
    function this = resetState( this )
      % Reset the internal state.
      
      this.board = zeros( this.rows, this.columns, 'uint8' );
      this.fallingPiece = floor(this.rstream.rand * 7 + 1);
      
      this.clearedRows = 0; this.totalClearedRows = 0;
      
      this = computeActions( this );
      
    end
    
    function this = advanceState( this, action )
      % Advance the internal state.
      
      % expand the action
      action = this.actions(action,:);
      
      % step
      [this, this.clearedRows] = dropPiece( this, action );
      this.fallingPiece = floor(this.rstream.rand * 7 + 1);
      this = computeActions( this );
      
      % add cleared rows to total score
      this.totalClearedRows = this.totalClearedRows + this.clearedRows;
      
      % visualize and delay
      if this.visualization ~= -1;
        visualizeState( this );
        if this.visualization > 0; pause( this.visualization ); else pause; end
      end
        
    end
    
    
    function ended = checkEndCondition( this )
      % Return 'true' if the episode end condition is met.
      
      ended = isempty(this.board);
    end
    
    function stateVec = generateVectorialState( this )
      % Generate a row vectorial representation of the internal state.
      
      stateVec = double(logical(this.board')); stateVec = stateVec(:)';
      stateVec(end+1) = this.fallingPiece;
    end
    
    function observation = generateObservation( this )
      % Generate a row observation vector from the internal state.
      
      observation = generateVectorialState( this );
    end
    
    function reward = generateReward( this )
      % Generate a scalar reward for the previous transition.
      
      reward = this.clearedRows;
    end
    
    
    function [this, clearedRows] = dropPiece( this, action )
      % drop the piece onto the wall and clear resulting full rows

      % explicate the rotated piece shape and horizontal position
      piece = this.pieces{this.fallingPiece}{action(1)};
      pieceHeightmap = this.pieceHeightmaps{this.fallingPiece}{action(1)};
      [pieceRows,pieceCols] = size(piece);
      col = action(2);
      
      %  find correct row (row = placement of the top row of the piece)
      for c=pieceCols:-1:1
        r_ = find( this.board(:,col-1+c), 1 ); if isempty(r_); r(c) = this.rows + 1; else r(c) = r_; end
      end
      row = min(r - pieceHeightmap);
      
      % episode ends if the board would overflow
      if row < 1; this.board = []; clearedRows = 0; return; end

      % land the piece here (use piece index as color)
      this.board(row:row+pieceRows-1,col:col+size(piece,2)-1) = ...
        this.board(row:row+pieceRows-1,col:col+size(piece,2)-1) + uint8(this.fallingPiece * piece);
      
      % find full rows
      fullRows = all(this.board, 2);

      % count the full rows
      clearedRows = sum(fullRows);

      % erase full rows, then add empty rows to the top
      if clearedRows > 0
        this.board(fullRows,:) = [];
        this.board = [ zeros(clearedRows,this.columns,'uint8'); this.board ];
      end

    end

  end
  
  
  % private methods begin
  
  
  methods (Access=private)
    
    function this = computeActions( this )
      % compute the action matrix
      
      this.actions = [];
      
      % loop through orientations
      for o=1:length(this.pieces{this.fallingPiece})
        
        % add actions for each possible positioning
        maxPos = this.columns - size( this.pieces{this.fallingPiece}{o}, 2) + 1;
        this.actions(end+1:end+maxPos,:) = [repmat(o,maxPos,1), (1:maxPos)'];
        
      end
      
    end
    
    function this = generatePieceOrientations( this )
      % fill in the remaining possible piece orientations into this.pieces
      
      % loop through pieces
      for p=1:length(this.pieces)
        
        % loop through the rest of the possible orientations (90' steps)
        piece = this.pieces{p}{1};
        for o=2:4
          
          % generate a new rotation (rotate by 90': mirror and flip)
          piece = piece(:,end:-1:1)';
          ok = true;
          
          % check if identical to an existing one
          for oprev=1:length(this.pieces{p});
            if isequal( piece, this.pieces{p}{oprev} ); ok = false; break; end
          end
          
          % add if not identical
          if ok; this.pieces{p}{end+1} = piece; end
          
        end
      end
    end
    
    function this = generatePieceHeightmaps( this )
      
      % loop through pieces and orientations
      for p=1:length(this.pieces)
        for o=1:length(this.pieces{p})
          
          % loop through columns
          for c=1:size(this.pieces{p}{o},2)
            this.pieceHeightmaps{p}{o}(c) = find( this.pieces{p}{o}(:,c), 1, 'last' );
          end
          
        end
      end
      
    end
    
  end
  
end
