//
//  RMTracker.h
//  Romo
//
//  Created on 7/15/13.
//  Copyright (c) 2013 Romotive. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <Romo/RMVision.h>
#import <Romo/RMCore.h>
#import "RMVoice.h"
#import "RMRomo.h"

@protocol RMTrackerDelegate <NSObject>

- (void)didFindObject:(NSString *)object;
- (void)didLoseTrackOfObject:(NSString *)object;

@end

@interface RMTracker : NSObject

@property (nonatomic, weak) id<RMTrackerDelegate> delegate;
@property (nonatomic, strong) RMRomo *Romo;

@property (nonatomic, readonly) float lastFaceLocation;

@property (nonatomic, readonly, getter=isSearching) BOOL searching;
@property (nonatomic, readonly, getter=isTracking) BOOL tracking;

-(void)trackObject:(RMObject *)object;
-(void)lookAtObject:(RMObject *)object;
-(void)lostTrackOfObject;

-(void)resetTracker;

@end
