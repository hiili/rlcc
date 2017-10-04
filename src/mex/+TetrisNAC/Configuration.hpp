/* Configuration.hpp */
#ifndef CONFIGURATION_HPP
#define CONFIGURATION_HPP




/* Tetris.cpp */

// value of the state part bias feature in a terminal state (type: double)
#define TERMINAL_BIAS_VALUE_S 0.0

// value of the advantage part bias feature in a terminal state (type: double)
#define TERMINAL_BIAS_VALUE_A 1.0


/* NaturalActorCritic.hpp */

// do not consider actions that are flagged as terminal? (type: bool)
#define REJECT_TERMINAL_ACTIONS true

// available modes for using the variance reduction trick introduced in Jan Peters' thesis and in his NAC paper
enum PetersTrickMode { PTM_OFF, PTM_ON, PTM_CORRECTED };

// the mode for the variance reduction trick by Peters. PTM_CORRECTED is implemented only in LSTDLambda!
const PetersTrickMode PETERS_TRICK_MODE = PTM_ON;




#endif
