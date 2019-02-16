//
//  GPUImageBrightHueSegmentation.m
//  RMVision
//
//  Created on 11/26/13.
//  Copyright (c) 2013 Romotive, Inc. All rights reserved.
//

#import "GPUImageBrightHueSegmentation.h"

@implementation GPUImageBrightHueSegmentation


NSString *const kGPUImageBrightHueSegmentationFragmentShaderString = SHADER_STRING
(
 precision highp float;
 
 varying highp vec2 textureCoordinate;
 
 uniform sampler2D inputImageTexture;
 
 uniform float hueLeftBound;
 uniform float hueRightBound;
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
 
#define GREEN 0.333
#define PINK 0.833
#define TOLERANCE 0.15
 
 void main()
{
    lowp vec4 textureColor = texture2D(inputImageTexture, textureCoordinate);
    highp vec3 hsv = rgb2hsv(textureColor.rgb);
    
    // Don't like this here - would rather apply a scaling based on a function
    if (hsv.x >= GREEN - TOLERANCE && hsv.x <= GREEN + TOLERANCE) {
        hsv.z *= 5.0;
    }
    
    if (hsv.x >= PINK - TOLERANCE && hsv.x <= PINK + TOLERANCE) {
        hsv.y *= 5.0;
    }
    
    // Wanted to use bool variables here but was getting a shader compiler error
    // Instead adding float to mimic simple logic
    float resultValue = 0.0;
    float leftStep = step(hueLeftBound, hsv.x);
    float rightStep = 1.0 - step(hueRightBound, hsv.x);
    
    if (hsv.y > saturation && hsv.z > brightness) {
        
        if (hueLeftBound < hueRightBound) {
            resultValue = leftStep + rightStep - 1.0;
        } else {
            resultValue = leftStep + rightStep;

        }
    }
    gl_FragColor = resultValue > 0.5 ? textureColor : vec4(0.0);

}
 );

#pragma mark -
#pragma mark Initialization and teardown

- (id)init;
{
    self = [super initWithFragmentShaderFromString:kGPUImageBrightHueSegmentationFragmentShaderString];
    
    if (self)
    {
        self.brightnessThreshold = 0.5;
        self.saturationThreshold = 0.5;
        
        // Default example - trigger on red hues
        self.hueLeftBound = 0.9;
        self.hueRightBound = 0.1;
    }
    return self;
}

#pragma mark -
#pragma mark Accessors

-(void)setSaturationThreshold:(float)saturationThreshold
{
    // Clamp to range [0.0, 1.0]
    _saturationThreshold = MAX(0.0, MIN(1.0, saturationThreshold));
    [self setFloat:_saturationThreshold forUniformName:@"saturation"];
}

-(void)setBrightnessThreshold:(float)brightnessThreshold
{
    // Clamp to range [0.0, 1.0]
    _brightnessThreshold = MAX(0.0, MIN(1.0, brightnessThreshold));
    [self setFloat:_brightnessThreshold forUniformName:@"brightness"];
}

// Hue is on a circle between 0.0 and 1.0. If it is out of that range, we should wrap it around.
-(void)setHueLeftBound:(float)hueLeftBound
{
    _hueLeftBound = hueLeftBound;
    
    while (_hueLeftBound < 0.0) {
        _hueLeftBound += 1.0;
    }
    
    while (_hueLeftBound > 1.0) {
        _hueLeftBound -= 1.0;
    }
    
    [self setFloat:_hueLeftBound forUniformName:@"hueLeftBound"];
}

-(void)setHueRightBound:(float)hueRightBound
{
    _hueRightBound = hueRightBound;
    
    while (_hueRightBound < 0.0) {
        _hueRightBound += 1.0;
    }
    
    while (_hueRightBound > 1.0) {
        _hueRightBound -= 1.0;
    }
    
    [self setFloat:_hueRightBound forUniformName:@"hueRightBound"];
}



@end
