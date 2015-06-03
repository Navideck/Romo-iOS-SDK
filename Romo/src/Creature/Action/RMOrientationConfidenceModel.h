//
//  RMOrientationConfidenceModel.h
//  Romo
//
//  Created on 7/18/13.
//  Copyright (c) 2013 Romotive. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface RMOrientationConfidenceModel : NSObject

- (void)objectSeenAt:(float)location;
- (int)mostProbableLocation;
- (void)resetConfidences;
- (void)stop;

@end
