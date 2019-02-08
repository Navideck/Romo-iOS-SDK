////////////////////////////////////////////////////////////////////////////////
//                             _
//                            | | (_)
//   _ __ ___  _ __ ___   ___ | |_ ___   _____
//  | '__/ _ \| '_ ` _ \ / _ \| __| \ \ / / _ \
//  | | | (_) | | | | | | (_) | |_| |\ V /  __/
//  |_|  \___/|_| |_| |_|\___/ \__|_| \_/ \___|
//
////////////////////////////////////////////////////////////////////////////////
//
//  RMVisionDebugBroker.h
//  RMVision
//
//  Created by Romotive on 4/2/13.
//  Copyright (c) 2013 Romotive. All rights reserved.
//
////////////////////////////////////////////////////////////////////////////////
#import <Foundation/Foundation.h>
#import "RMVision.h"

@interface RMVisionDebugBroker : NSObject

@property BOOL running;
@property int width;
@property int height;

@property (nonatomic, weak) RMVision *core;

@property (atomic) float fps;
@property (atomic) BOOL showFPS;

+ (RMVisionDebugBroker *)shared;

// Adding / removing output views
- (BOOL)addOutputView:(UIView *)view;
- (BOOL)removeOutputView:(UIView *)view;

// Called when vision is started
- (void)visionStarted;

- (void)objectAt:(CGRect)bounds
    withRotation:(float)rotation
        withName:(NSString *)objectName;

// Motion detection view
- (void)addMotionView;
- (void)updateMotionView:(UIImage *)newImage;
- (void)disableMotionView;

- (void)loseObject:(NSString *)objectId;


// Attention setting
- (void)setAttention:(CGPoint)attention;
- (void)loseAttention;

@end
