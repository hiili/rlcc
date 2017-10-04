/* Tetris.hpp */
// TODO: StepData -> StateData
// TODO: clean up observation logging
#ifndef TETRIS_HPP
#define TETRIS_HPP


#include "../MatlabRandStream.hpp"


#define ROWS 20
#define COLUMNS 10


#define STATEDIM (2 * COLUMNS - 1 + 3)
#define STATEACTIONDIM (2 * COLUMNS - 1 + 3 + 1)   // add the immediate reward feature, keep bias for completeness
#define MAXACTIONS (4 * COLUMNS)

#define OBSERVATIONLOGLENGTH 50000   // enough for gaining about 20,000 points
#define LOGOBSERVATIONS 0


typedef double ObservationLog[OBSERVATIONLOGLENGTH][STATEDIM];



class Tetris {
  
public:
  
  /* Data structure for passing information from the environment to the agent. Terminal states are not explicitly
   * signaled, but the observation is a zero vector and actionCount is zero. */
  struct StepData {
    double transitionReward;
    double observation[STATEDIM];
    double actions[MAXACTIONS][STATEACTIONDIM];
    bool isActionTerminal[MAXACTIONS];
    int actionCount;
  };
  
  // observation log
  ObservationLog * observationLog;
  
  // observation log index (points to the next free index)
  int observationLogInd;
  
  // outbound data for the current state
  StepData stepData;
  
  // episode counter
  int episode;
  
  // whether in terminal state
  bool terminalState;
  
  // rows cleared during the episode
  int totalClearedRows;
  
  
private:
  
  // number of orientations for each piece
  static const int pieceOrientationCounts[7];
  
  // widths of pieces: piece x orientation
  static const int pieceWidths[7][4];
  
  // widths of pieces: piece x orientation
  static const int pieceHeights[7][4];
  
  // number of actions for each piece
  static const int pieceActionCounts[7];
  
  // piece top edge heightmaps: piece x orientation x column
  static const int pieceTopHeightmaps[7][4][4];
  
  // piece bottom edge heightmaps: piece x orientation x column
  static const int pieceHeightmaps[7][4][4];
  
  // piece shapes: piece x orientation x row x column
  static const bool pieces[7][4][4][4];
  
  
  // board size
  int rows, columns;
  
  
  // random number generator
  MatlabRandStream rstream;
  
  // board state (hardwired size)
  bool board[ROWS][COLUMNS];
  
  // board heightmap: row index of the topmost filled cell in each column, or ROWS if the column is empty
  int boardHeightmap[COLUMNS];
  
  // min(boardHeightmap)
  int boardHeightmapMin;
  
  // currently falling piece index (0-6)
  int fallingPiece;
  
  // rows cleared during previous step
  int clearedRows;
  
  
  // state handling
  void resetState();
  void advanceState( int action );
  int dropPiece( int action );
  void shiftRows( int firstRow, int lastRow, int shift );
  
  // generate data for the agent
  void generateStepData();
  void computeObservation( double (& observation)[STATEDIM] );
  void computeActions();
  
  // logging
  void logState();
  void logReward();
  
  
public:
  
  Tetris( int rows, int columns, mxArray * rstream );
  ~Tetris();
  
  // start a new episode
  void newEpisode();
  
  // take a step. action is orientation-major. returns the immediate reward.
  double step( int action );
  
  // creates the return struct
  mxArray * createReturnStruct();
  
};




#endif
