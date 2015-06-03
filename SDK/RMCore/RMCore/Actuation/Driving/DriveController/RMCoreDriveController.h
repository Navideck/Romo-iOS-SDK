//
//  RMCoreDriveController.h
//  RMCore
//
//  Created on 2/27/13.
//  Copyright (c) 2013 Romotive. All rights reserved.
//
// RMCoreDriveController is a PID controller with a few extra variables to hold
// onto state that is specific to controlling robot drive motion
//

#import <Foundation/Foundation.h>
#import "RMCoreControllerPID.h"

@interface RMCoreDriveController : RMCoreControllerPID

// controller's current output values
@property (nonatomic) int leftWheelVal;
@property (nonatomic) int rightWheelVal;

// controller's target output values
@property (atomic) int targetLeftWheelVal;
@property (atomic) int targetRightWheelVal;

- (id)init;

// intialize PID controller for scalar input
-  (id) initWithFrequency:
                       (float)controlFrequency
          proportional:(float)P
              integral:(float)I
            derivative:(float)D
           inputSource:(RMControllerPIDInputSourceHandler)inputSourceHandler
            outputSink:(RMControllerPIDOutputSinkHandler)outputSinkHandler
       subtractionHandler:(RMControllerPIDSubtractionHandler)subtractionHandler;

@end
