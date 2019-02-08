//
//  GPUImageMaskToPixelPositionFilter.m
//  RMVision
//
//  Created on 10/15/13.
//  Copyright (c) 2013 Romotive, Inc. All rights reserved.
//

#import "GPUImageMaskToPixelPositionFilter.h"

@implementation GPUImageMaskToPixelPositionFilter

NSString *const kGPUImageMaskToPixelPositionFilterFragmentShaderString = SHADER_STRING
(
 precision highp float;
 varying highp vec2 textureCoordinate;
 uniform sampler2D inputImageTexture;
 
 void main()
{
	highp vec4 pixelColor;
    
	pixelColor = texture2D(inputImageTexture, textureCoordinate);   
    float pixelSum = dot(pixelColor.xyz, vec3(1.0));
    
    // Pass thru the pixel coordinate if the sum of RGB values is greater than 0.
    // Otherwise, set it to a zero vec4
	gl_FragColor = (pixelSum > 0.0) ?  vec4(textureCoordinate.xy, 0.0, 1.0) : vec4(0.0);
}
 );

#pragma mark -
#pragma mark Initialization and teardown

- (id)init;
{
    self = [super initWithFragmentShaderFromString:kGPUImageMaskToPixelPositionFilterFragmentShaderString];
    
    if (self)
    {

    }
    return self;
}

#pragma mark -
#pragma mark Accessors


@end
