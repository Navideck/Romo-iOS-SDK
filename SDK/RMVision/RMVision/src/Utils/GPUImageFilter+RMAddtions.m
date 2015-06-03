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
//  GPUImageFilter+RMAdditions.m
//      Category for extending the GPUImageFilter for
//  RMVision
//
//  Created on 09/23/13.
//  Copyright (c) 2013 Romotive. All rights reserved.
//
////////////////////////////////////////////////////////////////////////////////

#import "GPUImageFilter+RMAdditions.h"

@implementation GPUImageFilter (RMAdditions)

- (id)initWithFragmentShaderFromFile:(NSString *)fragmentShaderFilename inDirectory:(NSString *)subpath;
{
    
    NSString *fragmentShaderPathname = [[NSBundle mainBundle] pathForResource:fragmentShaderFilename ofType:@"fsh" inDirectory:subpath];
    NSString *fragmentShaderString = [NSString stringWithContentsOfFile:fragmentShaderPathname encoding:NSUTF8StringEncoding error:nil];
    
    if (!(self = [self initWithFragmentShaderFromString:fragmentShaderString]))
    {
		return nil;
    }
    
    return self;
}

+(GPUVector3)multiplyGPUVector3:(GPUVector3)vector byScaler:(float)scaler
{
    return (GPUVector3) { vector.one*scaler, vector.two*scaler, vector.three*scaler };
}

+(GPUMatrix3x3)multiplyGPUMatrix3x3:(GPUMatrix3x3)matrix byScaler:(float)scaler
{
    return (GPUMatrix3x3) {
        [self multiplyGPUVector3:matrix.one byScaler:scaler],
        [self multiplyGPUVector3:matrix.two byScaler:scaler],
        [self multiplyGPUVector3:matrix.three byScaler:scaler]};
}

@end


