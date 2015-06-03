//
//  RMBehaviorManager.h
//  Romo
//
//  Created on 7/22/13.
//  Copyright (c) 2013 Romotive. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "RMBehaviorMotivationTypes.h"

//@class RMMotivationManager;

@interface RMBehaviorManager : NSObject

@property (nonatomic) RMBehavior behavior;

- (id)initWithMotivation:(RMMotivation)motivation;

@end
