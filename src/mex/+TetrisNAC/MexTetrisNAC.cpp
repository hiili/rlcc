/* MexTetrisNAC.cpp
 *
 *   [environmentDataOut, agentDataOut] = MexTetrisNAC( environmentDataIn, agentDataIn, stopConds )
 *
 * This implementation runs only for a single episode, which is assumed in the Matlab implementation
 * AgentNaturalActorCritic (in mexJoin). We could, in principle, run several episodes, as long as we do not cross the
 * time instant when the actor or the critic is to be updated.
 *
 * This implementation produces exactly identical results with the Matlab implementation for the case of gamma=1
 * and lambda=0. In most cases however there will be slight rounding error differences in the critic statistics,
 * leading to very slightly differing results (tested with r108 trunk). (starting from around r383, the mex and
 * Matlab implementations have drifted away from each other)
 */


#include "Tetris.hpp"
#include "NaturalActorCritic.hpp"
#include "LSTDLambda.hpp"
#include "LSPELambda.hpp"
#include "../MatlabRandStream.hpp"

#include "mex.h"
#include "matrix.h"

#include <cstring>
using std::memcpy;




void mexFunction(
    int nlhs, mxArray * plhs[],
    int nrhs, const mxArray * prhs[])
{
  const mxArray * environmentData;
  const mxArray * agentData;
  const mxArray * stopConds;
  
  // check and get args
  mxAssert( nlhs == 2 && nrhs == 3, "Wrong number of arguments!" );
  environmentData = prhs[0];
  agentData = prhs[1];
  stopConds = prhs[2];
  
  // parse stopConds
  double scMaxSteps = mxGetScalar( mxGetField(stopConds, 0, "maxSteps") );
  double scTotalRewardMin = mxGetPr( mxGetField(stopConds, 0, "totalRewardRange") )[0];
  double scTotalRewardMax = mxGetPr( mxGetField(stopConds, 0, "totalRewardRange") )[1];
  
  // create and init the environment
  Tetris environment( 20, 10, mxGetField(environmentData, 0, "rstream") );
  
  // create and init the agent
  NaturalActorCritic agent( mxGetField(agentData, 0, "rstream"),
                            (int)(mxGetScalar( mxGetField(agentData, 0, "criticClass") )),
                            mxGetScalar( mxGetField(agentData, 0, "learning") ),
                            mxGetM( mxGetField(agentData, 0, "theta") ),
                            mxGetPr( mxGetField(agentData, 0, "theta") ),
                            mxGetScalar( mxGetField(agentData, 0, "gamma") ),
                            mxGetScalar( mxGetField(agentData, 0, "lambda") ),
                            mxGetScalar( mxGetField(agentData, 0, "tau") ) );
  
  
  // main loop
  int action;
  environment.newEpisode();
  agent.newEpisode();
  double totalReward = 0.0, reward, stepCounter = 0;
  while( !environment.terminalState &&
         totalReward >= scTotalRewardMin && totalReward <= scTotalRewardMax &&
         stepCounter < scMaxSteps ) {
    
    action = agent.step( environment.stepData );
    reward = environment.step( action );
    
    totalReward += reward; stepCounter++;
  }
  agent.step( environment.stepData );   // step in terminal state for learning purposes
  
  
  // create and assign return structs, then return
  plhs[0] = environment.createReturnStruct();
  plhs[1] = agent.createReturnStruct();
  return;
}
