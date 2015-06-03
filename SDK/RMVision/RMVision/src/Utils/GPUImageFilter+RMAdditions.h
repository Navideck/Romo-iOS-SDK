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
//  GPUImageFilter+RMAdditions.h
//      Category for extending the GPUImageFilter for
//  RMVision
//
//  Created on 09/23/13.
//  Copyright (c) 2013 Romotive. All rights reserved.
//
////////////////////////////////////////////////////////////////////////////////


#import "GPUImageFilter.h"

@interface GPUImageFilter (RMAdditions)


// Allows loading of a fragment shader from a file in a sub-bundle
- (id)initWithFragmentShaderFromFile:(NSString *)fragmentShaderFilename inDirectory:(NSString *)subpath;

+(GPUVector3)multiplyGPUVector3:(GPUVector3)vector byScaler:(float)scaler;
+(GPUMatrix3x3)multiplyGPUMatrix3x3:(GPUMatrix3x3)matrix byScaler:(float)scaler;

@end