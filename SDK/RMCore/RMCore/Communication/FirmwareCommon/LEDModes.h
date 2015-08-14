/*
 * LEDModes.h
 *
 * Created: 4/8/2013 5:29:21 PM
 *  Author: Aaron Solochek
 */ 


#ifndef LEDMODES_H_
#define LEDMODES_H_


typedef enum {
    RMLedModeOff,
    RMLedModePWM,
    RMLedModeBlink,
    RMLedModePulse,
    RMLedModeHalfPulseUp,
    RMLedModeHalfPulseDown
} RMLedMode;



#endif /* LEDMODES_H_ */