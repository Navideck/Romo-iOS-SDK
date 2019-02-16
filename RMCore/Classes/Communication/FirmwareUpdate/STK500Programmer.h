//
//  STK500Programmer.h
//  RMCore
//
//  Created on 2013-04-09.
//  Copyright (c) 2013 Romotive. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "IntelHexImage.h"
#import "SerialProtocol.h"
#import "RMProgrammingProtocol.h"

@interface STK500Programmer : NSObject <RMProgrammingProtocol>

- (void)sendNotification;

@end
