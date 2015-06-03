//
//  UIColor+RMColor.h
//  RUIActionBar
//

#import <UIKit/UIKit.h>

@interface UIColor (RMColor)

+ (UIColor *)romoBlue;
+ (UIColor *)romoWhite;
+ (UIColor *)romoLightGray;
+ (UIColor *)romoGray;
+ (UIColor *)romoDarkGray;
+ (UIColor *)romoBlack;
+ (UIColor *)romoTableCellWhite;
+ (UIColor *)blueTextColor;
+ (UIColor *)romoGreen;
+ (UIColor *)romoPurple;

- (UIColor *)colorWithSaturation:(CGFloat)saturation;
- (UIColor *)colorWithSaturation:(CGFloat)saturation brightness:(CGFloat)brightness;
- (UIColor *)colorWithMultipliedSaturation:(CGFloat)multipliedSaturation multipliedBrightness:(CGFloat)multipliedBrightness;

@end
