/* LSPELambda.cpp */


#include "LSPELambda.hpp"

#include "mex.h"

#include <cstring>
using std::memset;




LSPELambda::LSPELambda( int VDim, double gamma, double lambda ) :
  Critic( VDim, gamma, lambda )
{
  // check board size
  mxAssert( VDim == VDIM, "VDim must match the hard-coded value VDIM!" );
  
  // init params
  memset( this->B, 0, sizeof(this->B) );
  memset( this->A, 0, sizeof(this->A) );
  memset( this->b, 0, sizeof(this->b) );
  memset( this->z, 0, sizeof(this->z) );
}


void LSPELambda::step( double r )
{
  // update B
  for( int i = 0 ; i < this->VDim ; i++ )
    for( int j = 0 ; j < this->VDim ; j++ )
      this->B[i][j] += this->phi0[i] * this->phi0[j];
  
  // update z
  for( int i = 0 ; i < this->VDim ; i++ )
    this->z[i] = this->gamma * this->lambda * this->z[i] + phi0[i];
  
  // update A
  double tmp[VDIM];
  for( int i = 0 ; i < this->VDim ; i++ )
    tmp[i] = this->gamma * phi1[i] - phi0[i];
  for( int i = 0 ; i < this->VDim ; i++ )
    for( int j = 0 ; j < this->VDim ; j++ )
      this->A[i][j] += this->z[i] * tmp[j];
  
  // update b
  for( int i = 0 ; i < this->VDim ; i++ )
    this->b[i] += this->z[i] * r;
}


void LSPELambda::fillReturnStruct( mxArray * s )
{
  // add B
  mxArray * B = mxCreateDoubleMatrix( VDIM, VDIM, mxREAL );
  double * BData = mxGetPr(B);
  for( int row = 0 ; row < VDIM ; row++ )
    for( int col = 0 ; col < VDIM ; col++ )
      BData[col * VDIM + row] = this->B[row][col];   // shuffle from row-major (C) to column-major (Matlab)
  mxAddField( s, "B" );
  mxSetField( s, 0, "B", B );
  
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
