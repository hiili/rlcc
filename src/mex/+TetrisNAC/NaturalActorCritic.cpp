/* NaturalActorCritic.cpp
 *
 * NOTE: learning and acting are in reverse order in step() when compared to the Matlab implementation. This makes no
 * difference as long as policy updates are performed only in terminal states.
 */


#include "NaturalActorCritic.hpp"
#include "Critic.hpp"
#include "LSTDLambda.hpp"
#include "LSPELambda.hpp"
#include "FullTDLambda.hpp"
#include "Configuration.hpp"
#include "../MatlabRandStream.hpp"

#include "matrix.h"

#include <cstring>
using std::memcpy;
using std::memset;

#include <limits>
#define Inf (std::numeric_limits<double>::infinity())

#include <cmath>
using std::exp;




NaturalActorCritic::NaturalActorCritic( mxArray * rstream, int criticClass, bool learning,
                                        int thetaDim, const double * theta, double gamma, double lambda, double tau ) :
  critic( 0 ),
  rstream( rstream ),
  learning( learning ),
  thetaDim( thetaDim ),
  theta( theta ),
  tau( tau )
{
  // create the critic
  switch( (Critic::CriticClass)criticClass ) {
    case Critic::CC_LSTD:
      this->critic = new LSTDLambda( STATEDIM + STATEACTIONDIM, gamma, lambda );
      break;
    case Critic::CC_LSPE:
      this->critic = new LSPELambda( STATEDIM + STATEACTIONDIM, gamma, lambda );
      break;
    case Critic::CC_FULLTD:
      this->critic = new FullTDLambda( STATEDIM + STATEACTIONDIM, gamma, lambda );
      break;
    default:
      mxAssert( false, "Invalid critic class id!" );
  };
  
  // the policy gradient part of phi1 in the critic is always zero. set the entire phi1 to zero here and do not touch
  // the gradient part after this.
  memset( critic->phi1, 0, sizeof(critic->phi1) );
}

NaturalActorCritic::~NaturalActorCritic()
{
  // delete the critic
  delete this->critic; this->critic = 0;
}


void NaturalActorCritic::newEpisode()
{
  this->firstStep = true;
}


int NaturalActorCritic::step( const Tetris::StepData & stepData )
{
  // decide an action for the current step
  this->action = act( stepData );
  
  // learn?
  if( this->learning ) {
    
    // learn from the previous transition if not the first step
    if( !this->firstStep ) learn( this->prevStepData, this->prevActionProbabilities, this->prevAction,
            stepData, this->actionProbabilities, this->action );

    // shift the current state to appear as the previous state
    memcpy( &this->prevStepData, &stepData, sizeof(this->prevStepData) );
    memcpy( &this->prevActionProbabilities, &this->actionProbabilities, sizeof(this->prevActionProbabilities) );
    this->prevAction = this->action;
    
    // make sure that the episode start flag is down
    this->firstStep = false;
    
  }
  
  // return the action
  return this->action;
}


mxArray * NaturalActorCritic::createReturnStruct()
{
  mxArray * s = mxCreateStructMatrix( 1, 1, 0, 0 );
  mxArray * sc = mxCreateStructMatrix( 1, 1, 0, 0 );
  
  mxAddField( s, "critic" );
  mxSetField( s, 0, "critic", sc );
  
  critic->fillReturnStruct( sc );
  
  return s;
}




/* private methods */


/* Learn. This is not the first step (checked in step()), but it might be the last step. */
void NaturalActorCritic::learn( const Tetris::StepData & s0, const double (& pr0)[MAXACTIONS], int a0,
                                const Tetris::StepData & s1, const double (& pr1)[MAXACTIONS], int a1 )
{
  // load the state feature parts of phi0 and phi1 into the critic
  memcpy( this->critic->phi0, s0.observation, sizeof(s0.observation) );
  memcpy( this->critic->phi1, s1.observation, sizeof(s1.observation) );
  
  // load the gradient vector part of phi0:
  //   grad( log( pi(a0|s0) ) ) = phi(s,a) - sum_b( pi(b|s) phi(s,b) )
  memcpy( &this->critic->phi0[STATEDIM], s0.actions[a0], sizeof(s0.actions[a0]) );
  for( int action = 0 ; action < s0.actionCount ; action++ )
    for( int i = 0 ; i < STATEACTIONDIM ; i++ )
      this->critic->phi0[STATEDIM+i] -= pr0[action] * s0.actions[action][i];
  
  // if Peters' variance reduction trick is not enabled, then load also the gradient vector part of phi1, otherwise do
  // nothing (the gradient part of phi1 has been zeroed in the constructor)
  if( PETERS_TRICK_MODE == PTM_OFF ) {
    memcpy( &this->critic->phi1[STATEDIM], s1.actions[a1], sizeof(s1.actions[a1]) );
    for( int action = 0 ; action < s1.actionCount ; action++ )
      for( int i = 0 ; i < STATEACTIONDIM ; i++ )
        this->critic->phi1[STATEDIM+i] -= pr1[action] * s1.actions[action][i];
  }
  
  // step the critic
  critic->step( s1.transitionReward );
}


int NaturalActorCritic::act( const Tetris::StepData & s )
{
  computeActionProbabilities( s );
  return drawAction( s );
}


void NaturalActorCritic::computeActionProbabilities( const Tetris::StepData & s )
{
  // set to zero
  memset( this->actionProbabilities, 0, sizeof(this->actionProbabilities) );
  
  // (col)actionProbabilities = ((matrix)actions * (col)theta) / tau   (find maximum value for later use)
  double maxPr = -Inf;
  for( int action = 0 ; action < s.actionCount ; action++ ) {
    if( REJECT_TERMINAL_ACTIONS && s.isActionTerminal[action] ) {
      // disable
      this->actionProbabilities[action] = -Inf;
    } else {
      // add
      for( int i = 0 ; i < STATEACTIONDIM ; i++ )
        this->actionProbabilities[action] += (s.actions[action][i] * this->theta[i]) / this->tau;
    }
    // maintain max value
    if( this->actionProbabilities[action] > maxPr ) maxPr = this->actionProbabilities[action];
  }
  
  // (col)actionProbabilities = exp( (col)actionProbabilities - maxPr ) (avoid overflow, get sum for later use)
  double sumPr = 0.0;
  for( int action = 0 ; action < s.actionCount ; action++ ) {
    this->actionProbabilities[action] = exp( this->actionProbabilities[action] - maxPr );
    sumPr += this->actionProbabilities[action];
  }
  
  // (col)actionProbabilities = (col)actionProbabilities / sum( (col)actionProbabilities )
  for( int action = 0 ; action < s.actionCount ; action++ ) {
    this->actionProbabilities[action] /= sumPr;
  }
  
  // set to the uniform distribution if all actions had -Inf unnormalized probability
  if( maxPr == -Inf ) {
    for( int action = 0 ; action < s.actionCount ; action++ )
      this->actionProbabilities[action] = 1.0 / (double)s.actionCount;
  }
}


int NaturalActorCritic::drawAction( const Tetris::StepData & s )
{
  double r = this->rstream.rand();
  double sum = 0.0;
  int action;
  
  for( action = 0 ; action < s.actionCount ; action++ ) {
    sum += this->actionProbabilities[action];
    if( r < sum ) break;
  }
  if( action == s.actionCount ) action--;   // in case of numerical errors
  
  return action;
}
