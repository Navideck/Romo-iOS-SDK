/*
 * ChargingStates.h
 *
 * Created: 4/8/2013 5:18:19 PM
 *  Author: Aaron Solochek
 */ 


#ifndef CHARGINGSTATES_H_
#define CHARGINGSTATES_H_


typedef enum {
    RMChargingStateOff,
    RMChargingStateOn,
    RMChargingStateError,
    RMChargingStateUnknown
} RMChargingState;


#endif /* CHARGINGSTATES_H_ */