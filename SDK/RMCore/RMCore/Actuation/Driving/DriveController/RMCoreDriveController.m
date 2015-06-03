//
//  RMCoreDriveController.m
//  RMCore
//
//  Created on 2/27/13.
//  Copyright (c) 2013 Romotive. All rights reserved.
//

#import "RMCoreDriveController.h"

@interface RMCoreDriveController ()

@end

@implementation RMCoreDriveController

- (id)init
{
    self = [super init];
    return self;
}

// pass through to RMCoreControllerPID scalar controller initializer
- (id) initWithFrequency:
                          (float)controlFrequency
             proportional:(float)P
                 integral:(float)I
               derivative:(float)D
              inputSource:(RMControllerPIDInputSourceHandler)inputSourceHandler
               outputSink:(RMControllerPIDOutputSinkHandler)outputSinkHandler
       subtractionHandler:(RMControllerPIDSubtractionHandler)subtractionHandler
{
    self = [super initWithFrequency:controlFrequency
                      proportional:P
                          integral:I
                        derivative:D
                           setpoint:0
                       inputSource:inputSourceHandler
                        outputSink:outputSinkHandler
                subtractionHandler:subtractionHandler];

    return self;
}

@end