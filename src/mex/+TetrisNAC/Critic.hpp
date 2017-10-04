/* Critic.hpp */
#ifndef CRITIC_HPP
#define CRITIC_HPP


#include "matrix.h"


#define VDIM (22+23)




class Critic {
  
protected:
  
  // number of params
  int VDim;
  
  // learning params
  double gamma, lambda;
  
  
public:
  
  // critic classes
  enum CriticClass { CC_LSTD = 0, CC_LSPE = 1, CC_FULLTD = 2 };
  
  // input registers
  double phi0[VDIM];
  double phi1[VDIM];
  
  
  Critic( int VDim, double gamma, double lambda ) :
    VDim( VDim ),
    gamma( gamma ),
    lambda( lambda )
  {}
  
  // update statistics based on the data in the input registers
  virtual void step( double r ) = 0;
  
  // copy statistics into the provided return struct
  virtual void fillReturnStruct( mxArray * s ) = 0;
  
};




#endif
