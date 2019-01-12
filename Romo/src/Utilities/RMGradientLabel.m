//
//  RMGradientLabel.m
//  Romo
//

#import "RMGradientLabel.h"

@implementation RMGradientLabel

- (void)setGradientColor:(UIColor *)gradientColor
{
    _gradientColor = gradientColor;
    self.textColor = [UIColor colorWithPatternImage:[RMGradientLabel gradientImageForColor:gradientColor label:self]];
}

+ (UIImage *)gradientImageForColor:(UIColor *)color label:(UILabel *)label
{
    UIColor *startColor = nil;
    UIColor *endColor = nil;

    if ([color isEqual:[UIColor greenColor]]) {
        startColor = [UIColor colorWithHue:0.208 saturation:0.75 brightness:1.0 alpha:1.0];
        endColor = [UIColor colorWithHue:0.375 saturation:1.0 brightness:0.8 alpha:1.0];
    } else if ([color isEqual:[UIColor magentaColor]]) {
        startColor = [UIColor colorWithHue:0.939 saturation:0.54 brightness:1.0 alpha:1.0];
        endColor = [UIColor colorWithHue:0.939 saturation:0.9 brightness:0.9 alpha:1.0];
    }

    return [self gradientImageFromStartColor:startColor endColor:endColor label:label];
}

+ (UIImage *)gradientImageFromStartColor:(UIColor *)startColor endColor:(UIColor *)endColor label:(UILabel *)label
{
    if (label.text.length) {
        CGFloat r1, g1, b1, a1, r2, g2, b2, a2;
        [startColor getRed:&r1 green:&g1 blue:&b1 alpha:&a1];
        [endColor getRed:&r2 green:&g2 blue:&b2 alpha:&a2];

        CGSize textSize;
        if (@available(iOS 7.0, *)) {
            textSize = [label.text sizeWithAttributes:@{NSFontAttributeName:label.font}];
        } else {
            // Fallback on earlier versions
            textSize = [label.text sizeWithFont:label.font];
        }
        UIGraphicsBeginImageContext(textSize);
        CGContextRef context = UIGraphicsGetCurrentContext();
        UIGraphicsPushContext(context);
        CGColorSpaceRef rgbColorspace = CGColorSpaceCreateDeviceRGB();
        CGFloat locations[2] = { 0.0, 1.0 };
        CGFloat colors[8] = { r1, g1, b1, a1, r2, g2, b2, a2 };
        CGGradientRef gradient = CGGradientCreateWithColorComponents(rgbColorspace, colors, locations, 2);
        CGPoint topCenter = CGPointMake(0, 0);
        CGPoint bottomCenter = CGPointMake(0, textSize.height);

        CGContextDrawLinearGradient(context, gradient, topCenter, bottomCenter, 0);

        CGGradientRelease(gradient);
        CGColorSpaceRelease(rgbColorspace);

        UIGraphicsPopContext();
        UIImage *gradientImage = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();

        return  gradientImage;
    }
    return nil;
}

- (void)drawRect:(CGRect)rect
{
    self.gradientColor = _gradientColor;
    [super drawRect:rect];
}

@end
