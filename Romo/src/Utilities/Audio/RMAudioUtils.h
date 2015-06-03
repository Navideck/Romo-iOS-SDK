//
//  RMAudioUtils.h
//  Romo
//
//  Created on 11/22/13.
//  Copyright (c) 2013 Romotive. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "RMSoundEffect.h"

@interface RMAudioUtils : NSObject

+ (void)updateTrainingSoundAtProgress:(float)progress
                     withLastProgress:(float)lastProgress;

@end
