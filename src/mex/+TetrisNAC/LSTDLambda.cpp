/* LSTDLambda.cpp */


#include "LSTDLambda.hpp"
#include "Tetris.hpp"
#include "Configuration.hpp"

#include "mex.h"

#include <cstring>
using std::memset;




LSTDLambda::LSTDLambda( int VDim, double gamma, double lambda ) :
  Critic( VDim, gamma, lambda )
{
  // check board size
  mxAssert( VDim == VDIM, "VDim must match the hard-coded value VDIM!" );
  
  // init params
  memset( this->A, 0, sizeof(this->A) );
  memset( this->b, 0, sizeof(this->b) );
  memset( this->z, 0, sizeof(this->z) );
}


void LSTDLambda::step( double r )
{
  // store old z if needed
  double z0[VDIM];
  if( PETERS_TRICK_MODE == PTM_CORRECTED ) memcpy( &z0, &this->z, sizeof(z0) );
  
  // update z
  for( int i = 0 ; i < this->VDim ; i++ )
    this->z[i] = this->gamma * this->lambda * this->z[i] + phi0[i];
  
  // update A
  double tmp[VDIM];
  for( int i = 0 ; i < this->VDim ; i++ )
    tmp[i] = phi0[i] - this->gamma * phi1[i];
  for( int i = 0 ; i < this->VDim ; i++ )
    for( int j = 0 ; j < this->VDim ; j++ )
      this->A[i][j] += this->z[i] * tmp[j];
  
  // if the corrected version of Peters' trick is in use, then substract the correction term from A
  if( PETERS_TRICK_MODE == PTM_CORRECTED ) {
    for( int i = 0 ; i < this->VDim ; i++ )   // loop over z
      for( int j = STATEDIM ; j < this->VDim ; j++ )   // loop over advantage part of phi
        this->A[i][j] -= this->gamma * this->lambda * z0[i] * phi0[j];
  }
  
  // update b
  for( int i = 0 ; i < this->VDim ; i++ )
    this->b[i] += this->z[i] * r;
}


void LSTDLambda::fillReturnStruct( mxArray * s )
{
  // add A
  mxArray * A = mxCreateDoubleMatrix( VDIM, VDIM, mxREAL );
  double * AData = mxGetPr(A);
  for( int row = 0 ; row < VDIM ; row++ )
    for( int col = 0 ; col < VDIM ; col++ )
      AData[col * VDIM + row] = this->A[row][col];   // shuffle from row-major (C) to column-major (Matlab)
  mxAddField( s, "A" );
  mxSetField( s, 0, "A", A );
  
  // add b
  mxArray * b = mxCreateDoubleMatrix( VDIM, 1, mxREAL );
  double * bData = mxGetPr(b);
  memcpy( mxGetPr(b), this->b, sizeof(this->b) );
  mxAddField( s, "b" );
  mxSetField( s, 0, "b", b );
}
