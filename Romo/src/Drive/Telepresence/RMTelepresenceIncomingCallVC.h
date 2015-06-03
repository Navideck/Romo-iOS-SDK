//
//  RUITelepresenceIncomingCallVC.h
//  Romo3
//
//  Created on 5/6/13.
//  Copyright (c) 2013 Romotive. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "RMRobotController.h"

typedef void(^RUITelepresenceIncomingCallHandler)();

@interface RMTelepresenceIncomingCallVC : RMRobotController

@property (nonatomic, copy) RUITelepresenceIncomingCallHandler callAcceptedHandler;
@property (nonatomic, copy) RUITelepresenceIncomingCallHandler callRejectedHandler;

@end
