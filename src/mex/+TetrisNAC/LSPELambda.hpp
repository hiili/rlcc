/* LSPELambda.hpp */
#ifndef LSPELAMBDA_HPP
#define LSPELAMBDA_HPP


#include "Critic.hpp"




class LSPELambda :
  public Critic
{
  
  // params
  double B[VDIM][VDIM];
  double A[VDIM][VDIM];
  double b[VDIM];
  double z[VDIM];
  
  
public:
  
  LSPELambda( int VDim, double gamma, double lambda );
  
  // update statistics based on the data in the input registers
  virtual void step( double r );
  
  // copy statistics into the provided return struct
  virtual void fillReturnStruct( mxArray * s );
  
};




#endif
