//
//  MotorCommandTypes.h
//  RMCore
//
//  Created by Aaron Solochek on 2013-04-08.
//  Copyright (c) 2013 Romotive. All rights reserved.
//

#ifndef MOTORCOMMANDTYPES_H
#define MOTORCOMMANDTYPES_H

typedef enum {
    RMMotorCommandTypePWM,
    RMMotorCommandTypeCurrent,
    RMMotorCommandTypeVelocity,
    RMMotorCommandTypePosition,
    RMMotorCommandTypeTorque
} RMMotorCommandType;


#endif
