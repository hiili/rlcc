/* LSTDLambda.hpp */
#ifndef LSTDLAMBDA_HPP
#define LSTDLAMBDA_HPP


#include "Critic.hpp"




class LSTDLambda :
  public Critic
{
  
  // params
  double A[VDIM][VDIM];
  double b[VDIM];
  double z[VDIM];
  
  
public:
  
  LSTDLambda( int VDim, double gamma, double lambda );
  
  // update statistics based on the data in the input registers
  virtual void step( double r );
  
  // copy statistics into the provided return struct
  virtual void fillReturnStruct( mxArray * s );
  
};




#endif
