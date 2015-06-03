//
//  UIColor+RMColor.m
//  RUIActionBar
//

#import "UIColor+RMColor.h"

@implementation UIColor (RMColor)

+ (UIColor *)romoBlue
{
    return [UIColor colorWithRed:(1.0/255.0) green:(174.0/255.0) blue:(221.0/255.0) alpha:1.0];
}

+ (UIColor *)romoWhite
{
    return [UIColor colorWithWhite:1.0 alpha:1.0];
}

+ (UIColor *)romoLightGray
{
    return [UIColor colorWithWhite:0.8 alpha:1.0];
}

+ (UIColor *)romoGray
{
    return [UIColor colorWithWhite:0.55 alpha:1.0];
}

+ (UIColor *)romoDarkGray
{
    return [UIColor colorWithWhite:0.15 alpha:1.0];
}

+ (UIColor *)romoBlack
{
    return [UIColor colorWithWhite:0.0 alpha:1.0];
}

+ (UIColor *)romoTableCellWhite
{
    return [UIColor colorWithWhite:0.95 alpha:1.0];
}

+ (UIColor *)blueTextColor
{
    return [UIColor colorWithHue:0.5833 saturation:1.0 brightness:1.0 alpha:1.0];
}

+ (UIColor *)romoGreen
{
    return [UIColor colorWithHue:0.2889 saturation:0.72 brightness:0.90 alpha:1.0];
}

+ (UIColor *)romoPurple
{
    return [UIColor colorWithHue:0.7667 saturation:1.0 brightness:0.43 alpha:1.0];
}

- (UIColor *)colorWithSaturation:(CGFloat)saturation
{
    CGFloat hue, brightness, alpha;
    [self getHue:&hue saturation:nil brightness:&brightness alpha:&alpha];
    return [UIColor colorWithHue:hue saturation:saturation brightness:brightness alpha:alpha];
}

- (UIColor *)colorWithSaturation:(CGFloat)saturation brightness:(CGFloat)brightness
{
    CGFloat hue, alpha;
    [self getHue:&hue saturation:nil brightness:nil alpha:&alpha];
    return [UIColor colorWithHue:hue saturation:saturation brightness:brightness alpha:alpha];
}

- (UIColor *)colorWithMultipliedSaturation:(CGFloat)multipliedSaturation multipliedBrightness:(CGFloat)multipliedBrightness
{
    CGFloat hue, saturation, brightness, alpha;
    [self getHue:&hue saturation:&saturation brightness:&brightness alpha:&alpha];
    return [UIColor colorWithHue:hue
                      saturation:MIN(1.0, saturation * multipliedSaturation)
                      brightness:MIN(1.0, brightness * multipliedBrightness)
                           alpha:alpha];
}

@end
