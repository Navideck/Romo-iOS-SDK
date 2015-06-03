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
//  RMFaceDetectionModule.m
//      Uses OpenCV to perform facial detection
//  RMVision
//
//  Created by Romotive on 10/28/12.
//  Copyright (c) 2012 Romotive. All rights reserved.
//
////////////////////////////////////////////////////////////////////////////////
#import <Foundation/Foundation.h>
#import "RMVisionModuleProtocol.h"
#import "RMVisionModule.h"

@interface RMFaceDetectionModule : RMVisionModule
                    <RMVisionModuleProtocol, AVCaptureMetadataOutputObjectsDelegate>

@property (nonatomic) float timeout;
@property (nonatomic) BOOL  eyeDetectionEnabled;

@end
