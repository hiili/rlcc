/* MatlabRandStream.hpp
 *
 * Pulls random numbers from Matlab, so as to allow performing identical experiments using both mex and Matlab
 * implementations. See also src/util/MexCompatibleRandStream.m.
 *
 * Performance: reading a single random number at a time from Matlab yields approx. 3,000 rands/s, which is too slow.
 * Current implementation with a buffer of 1024 pulls approx. 25,000,000 rands/s.
 */
#ifndef MATLABRANDSTREAM
#define MATLABRANDSTREAM


#include "mex.h"
#include "matrix.h"


// Remember to keep this in sync with the constant in util/MexCompatibleRandStream.m
#define BUFFERSIZE 1024




class MatlabRandStream {
  
  mxArray * plhs[1];
  mxArray * prhs[3];
  
  double * buffer;
  int idx;
  
  /* Loads new data into the buffer. plhs[0] points to the mxArray and has to be initially null. Buffer will point to
   * the contained double data. */
  void loadBuffer()
  {
    // free old data
    if( this->plhs[0] ) mxDestroyArray( this->plhs[0] );
    
    // get new data
    int ret = mexCallMATLAB( 1, this->plhs, 3, this->prhs, "rand" );
    
    if( ret ) mexErrMsgIdAndTxt( "MatlabRandStream:mexCallMATLABFailed", "MatlabRandStream: mexCallMATLAB() failed!" );
    
    // set pointers
    this->buffer = mxGetPr( this->plhs[0] );
    this->idx = 0;
  }
  
  
public:
  
  MatlabRandStream( mxArray * rstream ) :
    idx(BUFFERSIZE)
  {
    // set up args for the matlab call
    this->plhs[0] = 0;   // must be set for loadBuffer()
    this->prhs[0] = rstream;
    this->prhs[1] = mxCreateDoubleScalar(BUFFERSIZE);
    this->prhs[2] = mxCreateDoubleScalar(1.0);
  }
  
  // return a single random number
  double rand() {
    if( this->idx == BUFFERSIZE ) loadBuffer();
    return this->buffer[this->idx++];
  }
  
};




#endif
