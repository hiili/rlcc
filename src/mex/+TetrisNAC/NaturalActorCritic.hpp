/* NaturalActorCritic.hpp
 *
 * NOTE: The implementation uses new and delete calls, which might leak memory if Matlab terminates the mex while
 * fetching more random numbers.
 *
 * NOTE: Actions leading to termination are handled differently here than in the Matlab implementation. TODO: add an
 * explicit "will terminate" feature to action features and use it in action selection, instead of disabling terminating
 * actions in a hard-coded manner.
 */
#ifndef NATURALACTORCRITIC_HPP
#define NATURALACTORCRITIC_HPP


#include "Tetris.hpp"
#include "Critic.hpp"
#include "LSTDLambda.hpp"
#include "LSPELambda.hpp"
#include "../MatlabRandStream.hpp"




class NaturalActorCritic {
  
  // random number generator
  MatlabRandStream rstream;
  
  // whether learning is enabled
  bool learning;
  
  // number of params
  int thetaDim;
  
  // params
  const double * theta;
  
  // policy temperature
  double tau;
  
  
  // whether a new episode has just begun
  bool firstStep;
  
  // copy of the StepData for the previous step
  Tetris::StepData prevStepData;
  
  // Action index. act() will set this based on the current state. learn() will see this on the
  // next step as the action of the then-previous step.
  int action, prevAction;
  
  // Normalized action probabilities. act() will set this based on the current state. learn() will see this on the
  // next step as the action probabilities of the then-previous step.
  double actionProbabilities[MAXACTIONS], prevActionProbabilities[MAXACTIONS];
  
  
  void learn( const Tetris::StepData & s0, const double (& pr0)[MAXACTIONS], int a0,
              const Tetris::StepData & s1, const double (& pr1)[MAXACTIONS], int a1 );
  int act( const Tetris::StepData & s );
  
  void computeActionProbabilities( const Tetris::StepData & s );
  int drawAction( const Tetris::StepData & s );
  
  
public:
  
  // critic
  Critic * critic;
  
  
  NaturalActorCritic( mxArray * rstream, int criticClass, bool learning,
                      int thetaDim, const double * theta, double gamma, double lambda, double tau );
  
  ~NaturalActorCritic();

  // begin a new episode
  void newEpisode();
  
  // take a step and return the index of the selected action
  int step( const Tetris::StepData & stepData );
  
  // creates the return struct
  mxArray * createReturnStruct();
  
};




#endif
