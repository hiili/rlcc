/* FullTDLambda.cpp */


#include "FullTDLambda.hpp"

#include "mex.h"

#include <cstring>
using std::memset;




FullTDLambda::FullTDLambda( int VDim, double gamma, double lambda ) :
  Critic( VDim, gamma, lambda )
{
  // check board size
  mxAssert( VDim == VDIM, "VDim must match the hard-coded value VDIM!" );
  
  // init params
  this->s0 = mxCreateDoubleMatrix( MAXSAMPLES, VDIM, mxREAL );
  this->s1 = mxCreateDoubleMatrix( MAXSAMPLES, VDIM, mxREAL );
  this->r = mxCreateDoubleMatrix( MAXSAMPLES, 1, mxREAL );
  mxAssert( this->s0 && this->s1 && this->r, "Out of memory!" );   // redundant when run as mex
  
  // init sample counter
  this->n = 0;
}


void FullTDLambda::step( double reward )
{
  // check that we have buffer space for this sample
  mxAssert( this->n < MAXSAMPLES, "Maximum number of samples has been exceeded!" );
  
  // init pointers
  double * s0 = mxGetPr( this->s0 );
  double * s1 = mxGetPr( this->s1 );
  double * r = mxGetPr( this->r );
  
  // add data
  for( int i = 0; i < this->VDim ; i++ ) {
    s0[i * MAXSAMPLES + this->n] = this->phi0[i];
    s1[i * MAXSAMPLES + this->n] = this->phi1[i];
  }
  r[this->n] = reward;
  
  // increment sample counter
  this->n++;
}


void FullTDLambda::fillReturnStruct( mxArray * s )
{
  // add s0, s1, r
  mxAddField( s, "s0" );
  mxSetField( s, 0, "s0", this->s0 );
  mxAddField( s, "s1" );
  mxSetField( s, 0, "s1", this->s1 );
  mxAddField( s, "r" );
  mxSetField( s, 0, "r", this->r );
  
  // add sample counter
  mxAddField( s, "n" );
  mxSetField( s, 0, "n", mxCreateDoubleScalar( this->n ) );
}
