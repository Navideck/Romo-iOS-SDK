//
//  GPUImageMotionSegmentation.m
//  RMVision
//
//  Created on 10/3/13.
//  Copyright (c) 2013 Romotive, Inc. All rights reserved.
//

#import "GPUImageMotionSegmentation.h"

#if TARGET_IPHONE_SIMULATOR || TARGET_OS_IPHONE
NSString *const kGPUImageMotionSegmentationFragmentShaderString = SHADER_STRING
(
 varying highp vec2 textureCoordinate;
 varying highp vec2 textureCoordinate2;
 
 uniform sampler2D inputImageTexture;
 uniform sampler2D inputImageTexture2;
 
 uniform highp float intensity;
 
 void main()
 {
     lowp vec3 currentImageColor = texture2D(inputImageTexture, textureCoordinate).rgb;
     lowp vec3 lowPassImageColor = texture2D(inputImageTexture2, textureCoordinate2).rgb;
     
     mediump float colorDistance = distance(currentImageColor, lowPassImageColor); // * 0.57735
     lowp float movementThreshold = step(0.2, colorDistance);
     
     gl_FragColor = movementThreshold * vec4(currentImageColor, 1.0);
 }
 );
#else
NSString *const kGPUImageMotionSegmentationFragmentShaderString = SHADER_STRING
(
 varying vec2 textureCoordinate;
 varying vec2 textureCoordinate2;
 
 uniform sampler2D inputImageTexture;
 uniform sampler2D inputImageTexture2;
 
 uniform float intensity;
 
 void main()
 {
     vec3 currentImageColor = texture2D(inputImageTexture, textureCoordinate).rgb;
     vec3 lowPassImageColor = texture2D(inputImageTexture2, textureCoordinate2).rgb;
     
     float colorDistance = distance(currentImageColor, lowPassImageColor); // * 0.57735
     float movementThreshold = step(0.2, colorDistance);
     
     gl_FragColor = movementThreshold * vec4(currentImageColor, 1.0);
 }
 );
#endif


@implementation GPUImageMotionSegmentation

@synthesize lowPassFilterStrength, motionDetectionBlock;

#pragma mark -
#pragma mark Initialization and teardown

- (id)init;
{
    if (!(self = [super init]))
    {
		return nil;
    }
    
    // Start with a low pass filter to define the component to be removed
    lowPassFilter = [[GPUImageLowPassFilter alloc] init];
    [self addFilter:lowPassFilter];
    
    // Take the difference of the current frame from the low pass filtered result to get the high pass
    frameComparisonFilter = [[GPUImageTwoInputFilter alloc] initWithFragmentShaderFromString:kGPUImageMotionSegmentationFragmentShaderString];
    [self addFilter:frameComparisonFilter];
    
    // Texture location 0 needs to be the original image for the difference blend
    [lowPassFilter addTarget:frameComparisonFilter atTextureLocation:1];
    
    self.initialFilters = [NSArray arrayWithObjects:lowPassFilter, frameComparisonFilter, nil];
    self.terminalFilter = frameComparisonFilter;
    
    self.lowPassFilterStrength = 0.5;
    
    return self;
}

#pragma mark -
#pragma mark Accessors

- (void)setLowPassFilterStrength:(CGFloat)newValue;
{
    lowPassFilter.filterStrength = newValue;
}

- (CGFloat)lowPassFilterStrength;
{
    return lowPassFilter.filterStrength;
}


@end
