//
//  RMInteractionScriptRuntime.h
//  Romo
//
//  Created on 8/14/13.
//  Copyright (c) 2013 Romotive. All rights reserved.
//
#import "RMRobotController.h"

@interface RMInteractionScriptRuntime : RMRobotController

@property (nonatomic, copy) void (^completion)(BOOL);

-(id)initWithScript:(NSDictionary *)script;
-(id)initWithJSON:(NSString *)json;
-(id)initWithJSONPath:(NSString *)path;

@end
