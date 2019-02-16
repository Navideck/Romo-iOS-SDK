//
//  GPUImageBrightColorNotchFilter.m
//  RMVision
//
//  Created on 10/2/13.
//  Copyright (c) 2013 Romotive, Inc. All rights reserved.
//

#import "GPUImageBrightColorNotchFilter.h"

@implementation GPUImageBrightColorNotchFilter


NSString *const kGPUImageBrightColorNotchFilterFragmentShaderString = SHADER_STRING
(
 precision highp float;
 
 varying highp vec2 textureCoordinate;
 
 uniform sampler2D inputImageTexture;
 
 uniform float saturation;
 uniform float brightness;
 
 // Color conversion functions taken from http://lolengine.net/blog/2013/07/27/rgb-to-hsv-in-glsl
 
 lowp vec3 rgb2hsv(lowp vec3 c)
{
    vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
    vec4 p = c.g < c.b ? vec4(c.bg, K.wz) : vec4(c.gb, K.xy);
    vec4 q = c.r < p.x ? vec4(p.xyw, c.r) : vec4(c.r, p.yzx);
    
    float d = q.x - min(q.w, q.y);
    float e = 1.0e-10;
    return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}
 
 lowp vec3 hsv2rgb(lowp vec3 c)
{
    vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}
 
#define GREEN 0.333
#define PINK 0.833
 
 void main()
{
    lowp vec4 textureColor = texture2D(inputImageTexture, textureCoordinate);
    highp vec3 hsv = rgb2hsv(textureColor.rgb);
    lowp vec4 outputColor;
    
    float tolerance = 0.15;
    
    float numDivision = 10.0;
    hsv.x = floor(hsv.x*numDivision)/numDivision;
    
    if (hsv.x >= GREEN - tolerance && hsv.x <= GREEN + tolerance)
    {
        hsv.z *= 5.0;
    }
    
    
    if (hsv.x >= PINK - tolerance && hsv.x <= PINK + tolerance)
    {
        hsv.y *= 5.0;
    }
    
    if (hsv.y > saturation && hsv.z > brightness)
    {
        
        hsv.y = 1.0;
        hsv.z = 1.0;
        
    }
    else
    {
        hsv = vec3(0.0);
        textureColor = vec4(0.0);
    }
    
    gl_FragColor = textureColor;
}
 );

#pragma mark -
#pragma mark Initialization and teardown

- (id)init;
{
    self = [super initWithFragmentShaderFromString:kGPUImageBrightColorNotchFilterFragmentShaderString];
    
    if (self)
    {
        self.brightnessThreshold = 0.5;
        self.saturationThreshold = 0.5;
    }
    return self;
}

#pragma mark -
#pragma mark Accessors

-(void)setSaturationThreshold:(float)saturationThreshold
{
    _saturationThreshold = saturationThreshold;
    [self setFloat:saturationThreshold forUniformName:@"saturation"];
}

-(void)setBrightnessThreshold:(float)brightnessThreshold
{
    _brightnessThreshold = brightnessThreshold;
    [self setFloat:brightnessThreshold forUniformName:@"brightness"];
}

@end
