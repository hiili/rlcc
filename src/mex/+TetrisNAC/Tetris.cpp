/* Tetris.cpp
 *
 * Terminal state features
 * -----------------------
 *
 * The state observation vector of a terminal state is always a zero vector, except for the bias feature, which is set
 * to TERMINAL_BIAS_VALUE_S.
 *
 * The action observation vector of an action that leads to termination is always a zero vector, except:
 *   - The bias feature is set to TERMINAL_BIAS_VALUE_A.
 *   - The immediate reward feature is set to the actual immediate reward. For example, if the action clears one line
 *     and then leads to termination, then this feature will be set to 1.
 */


#include "Tetris.hpp"
#include "Configuration.hpp"
#include "../MatlabRandStream.hpp"
#include "../../../external/SeedFill.hpp"

#include "mex.h"
#include "matrix.h"

#include <cstring>
using std::memcpy;
using std::memset;


#define ABS(x) ((x)<0?-(x):(x))


#define HD_COVEREDBY 0
#define HD_UNDERTOPLINE 1
#define HD_FLOODFILL 2
#define HOLEDEFINITION HD_UNDERTOPLINE




/* private methods */


void Tetris::resetState()
{
  // clear board
  for( int row=0 ; row<this->rows ; row++ )
    for( int col=0 ; col<this->columns ; col++ )
      this->board[row][col] = false;
  
  // reset heightmap
  for( int col=0 ; col<this->columns ; col++ )
    this->boardHeightmap[col] = ROWS;
  this->boardHeightmapMin = ROWS;
  
  // set falling piece
  this->fallingPiece = (int)(this->rstream.rand() * 7.0);
  
  // clear scores and the terminal state flag
  this->clearedRows = 0; this->totalClearedRows = 0;
  this->terminalState = false;
}


void Tetris::advanceState( int action )
{
  // drop the piece and add score
  this->clearedRows = dropPiece( action );
  this->totalClearedRows += this->clearedRows;
  
  // randomize a new falling piece
  this->fallingPiece = (int)(this->rstream.rand() * 7.0);
}


/* Will update the board, its heightmap, min(heightmap), and the terminal state flag. */
int Tetris::dropPiece( int action )
{
  // expand the action
  int orientation, column;
  for( orientation = 0 ; orientation < this->pieceOrientationCounts[this->fallingPiece] ; orientation++ ) {
    
    if( action < this->columns - this->pieceWidths[this->fallingPiece][orientation] + 1 ) break;
    action -= this->columns - this->pieceWidths[this->fallingPiece][orientation] + 1;
    
  }
  column = action;
  
  // explicate piece shape information
  const bool (& piece)[4][4]( this->pieces[this->fallingPiece][orientation] );
  const int (& pieceTopHeightmap)[4]( this->pieceTopHeightmaps[this->fallingPiece][orientation] );
  const int (& pieceHeightmap)[4]( this->pieceHeightmaps[this->fallingPiece][orientation] );
  int pieceHeight = this->pieceHeights[this->fallingPiece][orientation];
  int pieceWidth = this->pieceWidths[this->fallingPiece][orientation];
  
  // find row (topmost row of the piece)
  int rowc, row = ROWS;
  for( int pieceColumn = 0 ; pieceColumn < pieceWidth ; pieceColumn++ ) {
    rowc = this->boardHeightmap[column+pieceColumn] - pieceHeightmap[pieceColumn];
    if( rowc < row ) row = rowc;
  }
  
  // flag terminal state and return if the board would overflow
  if( row < 0 ) {
    this->terminalState = true;
    return 0;
  }
  
  // place the piece to the board
  for( int pieceRow = 0 ; pieceRow < pieceHeight ; pieceRow++ )
    for( int pieceColumn = 0 ; pieceColumn < pieceWidth ; pieceColumn++ )
      this->board[row+pieceRow][column+pieceColumn] |= piece[pieceRow][pieceColumn];
  
  // update the heightmap
  for( int pieceColumn = 0 ; pieceColumn < pieceWidth ; pieceColumn++ ) {
    
    // set heightmap element
    this->boardHeightmap[column+pieceColumn] = row + pieceTopHeightmap[pieceColumn];
    
    // maintain min(heightmap)
    if( this->boardHeightmap[column+pieceColumn] < this->boardHeightmapMin )
      this->boardHeightmapMin = this->boardHeightmap[column+pieceColumn];
    
  }
  
  // scan affected region for filled rows, shift down within the region
  int filledRows = 0;
  for( int pieceRow = 0 ; pieceRow < pieceHeight ; pieceRow++ ) {
    
    // check this row
    int col;
    for( col = 0 ; col < this->columns ; col++ ) {
      if( !this->board[row+pieceRow][col] ) break;
    }
    
    // is it full?
    if( col == this->columns ) {
      // increment counter and shift down rows within the region
      filledRows++;
      shiftRows( row, row+pieceRow-1, 1 );
    }
    
  }
  
  // if full rows were found and cleared, then shift down the rows above the region and update the heightmap and
  // min(heightmap)
  if( filledRows > 0 ) {
    
    shiftRows( this->boardHeightmapMin, row - 1, filledRows );
    
    // update min(heightmap) (there can't be empty rows below the cleared rows)
    this->boardHeightmapMin += filledRows;
    
    // update the heightmap
    for( int row, col = 0 ; col < this->columns ; col++ ) {
      for( row = this->boardHeightmapMin ; row < this->rows && !this->board[row][col] ; row++ );
      this->boardHeightmap[col] = row;
    }
    
  }
  
  // return the number of cleared rows
  return filledRows;
}


void Tetris::shiftRows( int firstRow, int lastRow, int shift )
{
  // copy downwards
  for( int row = lastRow ; row >= firstRow ; row-- )
    for( int col = 0 ; col < this->columns ; col++ )
      this->board[row+shift][col] = this->board[row][col];
  
  // clear the new top rows
  for( int row = firstRow ; row < firstRow + shift ; row++ )
    for( int col = 0 ; col < this->columns ; col++ ) {
      this->board[row][col] = false;
    }
}


void Tetris::generateStepData()
{
  this->stepData.transitionReward = this->clearedRows;
  computeObservation( this->stepData.observation );
  computeActions();
}


void Tetris::computeObservation( double (& observation)[STATEDIM] )
{
  mxAssert( STATEDIM == 2 * this->columns - 1 + 3, "Unexpected STATEDIM!" );
  
  // terminal state? value == 0 -> observation == zero vector (bias value depends on configuration)
  if( this->terminalState ) {
    memset( observation, 0, sizeof(observation) );
    observation[2 * this->columns - 1 + 2] = TERMINAL_BIAS_VALUE_S;
    return;
  }
  
  // fill in columns heights and height differences
  for( int col = 0 ; col < this->columns ; col++ ) {
    observation[col] = this->rows - this->boardHeightmap[col];   // heights
    if( col >= 1 ) observation[this->columns + col - 1] = ABS( observation[col] - observation[col-1] );   // hdiffs
  }
  
  // set maximum column height
  observation[2 * this->columns - 1 + 0] = this->rows - this->boardHeightmapMin;
  
  // set number of holes
  int holes = 0;
  switch( HOLEDEFINITION ) {
    
    case HD_COVEREDBY:
      for( int row = this->boardHeightmapMin + 1 ; row < this->rows ; row++ )   // scan rows in the active region
        for( int col = 0 ; col < this->columns ; col++ )
          if( !this->board[row][col] && this->board[row-1][col] ) holes++;
      break;
      
    case HD_UNDERTOPLINE:
      for( int col = 0 ; col < this->columns ; col++ )
        for( int row = this->boardHeightmap[col] + 1 ; row < this->rows ; row++ )  // scan cells below the topline
          if( !this->board[row][col] ) holes++;
      break;
      
    case HD_FLOODFILL:
      bool board_[ROWS][COLUMNS];
      SFWindow win = { 0, this->boardHeightmapMin, this->columns-1, this->rows-1 };
      memcpy( board_, this->board, sizeof(board_) );
      for( int col = 0 ; col < this->columns ; col++ ) {
        SeedFill( board_, this->rows, this->columns, col, this->boardHeightmapMin, &win, true );
        for( int row = this->boardHeightmap[col] + 1 ; row < this->rows ; row++ )  // scan cells below the topline
          if( !board_[row][col] ) holes++;
      }
      break;
  }
  observation[2 * this->columns - 1 + 1] = holes;
  
  // set bias
  observation[2 * this->columns - 1 + 2] = 1.0;
}


void Tetris::computeActions()
{
  mxAssert( STATEACTIONDIM == 2 * this->columns - 1 + 4, "Unexpected STATEACTIONDIM!" );
  mxAssert( STATEDIM <= STATEACTIONDIM, "STATEDIM must be <= STATEACTIONDIM!" );
  
  // if terminal state, then set actionCount to zero and return
  if( this->terminalState ) {
    this->stepData.actionCount = 0;
    return;
  }
  
  
  // state backup variables
  bool origBoard[ROWS][COLUMNS];
  int origBoardHeightmap[COLUMNS];
  int origBoardHeightmapMin;
  
  // other variables
  int clearedRows;
  
  
  // take a snapshot of member fields that are to be modified
  memcpy( origBoard, this->board, sizeof(origBoard) );
  memcpy( origBoardHeightmap, this->boardHeightmap, sizeof(origBoardHeightmap) );
  origBoardHeightmapMin = this->boardHeightmapMin;
  
  // set number of actions
  this->stepData.actionCount = this->pieceActionCounts[this->fallingPiece];
  
  // loop through available actions
  for( int action = 0 ; action < this->stepData.actionCount ; action++ ) {
    
    // drop the piece
    clearedRows = dropPiece( action );
    
    // write the state observation vector to the action row
    computeObservation( (double (&)[STATEDIM])this->stepData.actions[action] );
    
    // if in terminal state, set the bias feature to the value specified in configuration
    if( this->terminalState ) this->stepData.actions[action][2 * this->columns - 1 + 2] = TERMINAL_BIAS_VALUE_A;
    
    // add the immediate reward feature
    this->stepData.actions[action][2 * this->columns - 1 + 3] = clearedRows;
    
    // set the terminal flag for the action
    this->stepData.isActionTerminal[action] = this->terminalState;
    
    // revert the state (this was optimized in r222 and then reverted in r223: the speed gain was negligible)
    memcpy( this->board, origBoard, sizeof(this->board) );
    memcpy( this->boardHeightmap, origBoardHeightmap, sizeof(this->boardHeightmap) );
    this->boardHeightmapMin = origBoardHeightmapMin;
    this->terminalState = false;
    
  }
}


void Tetris::logState()
{
  if( !LOGOBSERVATIONS ) return;
  
  // log the observation (other logging is not yet implemented)
  if( this->observationLogInd < OBSERVATIONLOGLENGTH )
    memcpy( (*this->observationLog)[this->observationLogInd++], this->stepData.observation,
            sizeof(this->stepData.observation) );
}


void Tetris::logReward()
{}




/* public methods */


Tetris::Tetris( int rows, int columns, mxArray * rstream ) :
  observationLog( (ObservationLog *)mxMalloc( sizeof(ObservationLog) ) ),
  observationLogInd( 0 ),
  rows( rows ), columns( columns ),
  rstream( rstream ),
  episode( 0 )
{
  // check memory allocation
  mxAssert( this->observationLog, "Failed to allocate memory!" );
  
  // check board size
  mxAssert( this->rows == ROWS && this->columns == COLUMNS, "The board size must match the hard-coded size!" );
}

Tetris::~Tetris()
{
  // causes occasional double-frees if ctrl-c. why? mxFree( this->observationLog ); this->observationLog = 0;
}


void Tetris::newEpisode()
{
  resetState();
  generateStepData();
  this->episode++;
}

double Tetris::step( int action )
{
  logState();
  advanceState( action );
  generateStepData();
  logReward();
  
  return this->clearedRows;
}


mxArray * Tetris::createReturnStruct()
{
  mxArray * s = mxCreateStructMatrix( 1, 1, 0, 0 );
  
  // add return
  mxAddField( s, "return" );
  mxSetField( s, 0, "return", mxCreateDoubleScalar( this->totalClearedRows ) );
  
  // add observation log
  mxArray * olog = mxCreateDoubleMatrix( this->observationLogInd, STATEDIM, mxREAL );
  double * ologData = mxGetPr(olog);
  for( int row = 0 ; row < this->observationLogInd ; row++ )
    for( int col = 0 ; col < STATEDIM ; col++ )
      ologData[col * this->observationLogInd + row] = (*this->observationLog)[row][col]; // shuffle row-maj. to col-maj.
  mxAddField( s, "observationLog" );
  mxSetField( s, 0, "observationLog", olog );
  
  return s;
}




/* constants */


const int Tetris::pieceOrientationCounts[7] = { 1, 4, 2, 4, 4, 2, 2 };

const int Tetris::pieceWidths[7][4] = {
  {2, 0, 0, 0},
  {3, 2, 3, 2},
  {4, 1, 0, 0},
  {3, 2, 3, 2},
  {3, 2, 3, 2},
  {3, 2, 0, 0},
  {3, 2, 0, 0},
};

const int Tetris::pieceHeights[7][4] = {
  {2, 0, 0, 0},
  {2, 3, 2, 3},
  {1, 4, 0, 0},
  {2, 3, 2, 3},
  {2, 3, 2, 3},
  {2, 3, 0, 0},
  {2, 3, 0, 0},
};

const int Tetris::pieceActionCounts[7] = {
  COLUMNS-1,
  COLUMNS-2 + COLUMNS-1 + COLUMNS-2 + COLUMNS-1,
  COLUMNS-3 + COLUMNS-0,
  COLUMNS-2 + COLUMNS-1 + COLUMNS-2 + COLUMNS-1,
  COLUMNS-2 + COLUMNS-1 + COLUMNS-2 + COLUMNS-1,
  COLUMNS-2 + COLUMNS-1,
  COLUMNS-2 + COLUMNS-1
};

const int Tetris::pieceTopHeightmaps[7][4][4] = {
  {{0, 0, 0, 0},
   {0, 0, 0, 0},
   {0, 0, 0, 0},
   {0, 0, 0, 0}},
  {{1, 0, 1, 0},
   {1, 0, 0, 0},
   {0, 0, 0, 0},
   {0, 1, 0, 0}},
  {{0, 0, 0, 0},
   {0, 0, 0, 0},
   {0, 0, 0, 0},
   {0, 0, 0, 0}},
  {{0, 1, 1, 0},
   {2, 0, 0, 0},
   {0, 0, 0, 0},
   {0, 0, 0, 0}},
  {{1, 1, 0, 0},
   {0, 0, 0, 0},
   {0, 0, 0, 0},
   {0, 2, 0, 0}},
  {{0, 0, 1, 0},
   {1, 0, 0, 0},
   {0, 0, 0, 0},
   {0, 0, 0, 0}},
  {{1, 0, 0, 0},
   {0, 1, 0, 0},
   {0, 0, 0, 0},
   {0, 0, 0, 0}}
};

const int Tetris::pieceHeightmaps[7][4][4] = {
  {{2, 2, 0, 0},
   {0, 0, 0, 0},
   {0, 0, 0, 0},
   {0, 0, 0, 0}},
  {{2, 2, 2, 0},
   {2, 3, 0, 0},
   {1, 2, 1, 0},
   {3, 2, 0, 0}},
  {{1, 1, 1, 1},
   {4, 0, 0, 0},
   {0, 0, 0, 0},
   {0, 0, 0, 0}},
  {{2, 2, 2, 0},
   {3, 3, 0, 0},
   {1, 1, 2, 0},
   {3, 1, 0, 0}},
  {{2, 2, 2, 0},
   {1, 3, 0, 0},
   {2, 1, 1, 0},
   {3, 3, 0, 0}},
  {{1, 2, 2, 0},
   {3, 2, 0, 0},
   {0, 0, 0, 0},
   {0, 0, 0, 0}},
  {{2, 2, 1, 0},
   {2, 3, 0, 0},
   {0, 0, 0, 0},
   {0, 0, 0, 0}}
};

const bool Tetris::pieces[7][4][4][4] = {
  {{{1, 1, 0, 0},
    {1, 1, 0, 0},
    {0, 0, 0, 0},
    {0, 0, 0, 0}},
   {{0, 0, 0, 0},
    {0, 0, 0, 0},
    {0, 0, 0, 0},
    {0, 0, 0, 0}},
   {{0, 0, 0, 0},
    {0, 0, 0, 0},
    {0, 0, 0, 0},
    {0, 0, 0, 0}},
   {{0, 0, 0, 0},
    {0, 0, 0, 0},
    {0, 0, 0, 0},
    {0, 0, 0, 0}}},
  {{{0, 1, 0, 0},
    {1, 1, 1, 0},
    {0, 0, 0, 0},
    {0, 0, 0, 0}},
   {{0, 1, 0, 0},
    {1, 1, 0, 0},
    {0, 1, 0, 0},
    {0, 0, 0, 0}},
   {{1, 1, 1, 0},
    {0, 1, 0, 0},
    {0, 0, 0, 0},
    {0, 0, 0, 0}},
   {{1, 0, 0, 0},
    {1, 1, 0, 0},
    {1, 0, 0, 0},
    {0, 0, 0, 0}}},
  {{{1, 1, 1, 1},
    {0, 0, 0, 0},
    {0, 0, 0, 0},
    {0, 0, 0, 0}},
   {{1, 0, 0, 0},
    {1, 0, 0, 0},
    {1, 0, 0, 0},
    {1, 0, 0, 0}},
   {{0, 0, 0, 0},
    {0, 0, 0, 0},
    {0, 0, 0, 0},
    {0, 0, 0, 0}},
   {{0, 0, 0, 0},
    {0, 0, 0, 0},
    {0, 0, 0, 0},
    {0, 0, 0, 0}}},
  {{{1, 0, 0, 0},
    {1, 1, 1, 0},
    {0, 0, 0, 0},
    {0, 0, 0, 0}},
   {{0, 1, 0, 0},
    {0, 1, 0, 0},
    {1, 1, 0, 0},
    {0, 0, 0, 0}},
   {{1, 1, 1, 0},
    {0, 0, 1, 0},
    {0, 0, 0, 0},
    {0, 0, 0, 0}},
   {{1, 1, 0, 0},
    {1, 0, 0, 0},
    {1, 0, 0, 0},
    {0, 0, 0, 0}}},
  {{{0, 0, 1, 0},
    {1, 1, 1, 0},
    {0, 0, 0, 0},
    {0, 0, 0, 0}},
   {{1, 1, 0, 0},
    {0, 1, 0, 0},
    {0, 1, 0, 0},
    {0, 0, 0, 0}},
   {{1, 1, 1, 0},
    {1, 0, 0, 0},
    {0, 0, 0, 0},
    {0, 0, 0, 0}},
   {{1, 0, 0, 0},
    {1, 0, 0, 0},
    {1, 1, 0, 0},
    {0, 0, 0, 0}}},
  {{{1, 1, 0, 0},
    {0, 1, 1, 0},
    {0, 0, 0, 0},
    {0, 0, 0, 0}},
   {{0, 1, 0, 0},
    {1, 1, 0, 0},
    {1, 0, 0, 0},
    {0, 0, 0, 0}},
   {{0, 0, 0, 0},
    {0, 0, 0, 0},
    {0, 0, 0, 0},
    {0, 0, 0, 0}},
   {{0, 0, 0, 0},
    {0, 0, 0, 0},
    {0, 0, 0, 0},
    {0, 0, 0, 0}}},
  {{{0, 1, 1, 0},
    {1, 1, 0, 0},
    {0, 0, 0, 0},
    {0, 0, 0, 0}},
   {{1, 0, 0, 0},
    {1, 1, 0, 0},
    {0, 1, 0, 0},
    {0, 0, 0, 0}},
   {{0, 0, 0, 0},
    {0, 0, 0, 0},
    {0, 0, 0, 0},
    {0, 0, 0, 0}},
   {{0, 0, 0, 0},
    {0, 0, 0, 0},
    {0, 0, 0, 0},
    {0, 0, 0, 0}}}
};
