//
//  RMTelepresenceHostRobotController.h
//  Romo
//
//  Created on 11/5/13.
//  Copyright (c) 2013 Romotive. All rights reserved.
//

#import "RMRobotController.h"

typedef void(^RMTelepresence2HostRobotControllerCompletion)(NSError *error);

@interface RMTelepresenceHostRobotController : RMRobotController

- (instancetype)initWithUUID:(NSString *)uuid
                   sessionID:(NSString *)otSessionID
                       token:(NSString *)otToken
                  completion:(RMTelepresence2HostRobotControllerCompletion)completion;

- (void)endSessionWithCompletion:(void(^)())completion;

@end
