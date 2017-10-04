/* FullTDLambda.hpp */
#ifndef FULLTDLAMBDA_HPP
#define FULLTDLAMBDA_HPP


#include "Critic.hpp"
#include "matrix.h"


#define MAXSAMPLES 1000000




class FullTDLambda :
  public Critic
{
  
  // params
  mxArray *s0;
  mxArray *s1;
  mxArray *r;
  
  // sample counter
  int n;
  
  
public:
  
  FullTDLambda( int VDim, double gamma, double lambda );
  
  // update statistics based on the data in the input registers
  virtual void step( double reward );
  
  // copy statistics into the provided return struct
  virtual void fillReturnStruct( mxArray * s );
  
};




#endif
