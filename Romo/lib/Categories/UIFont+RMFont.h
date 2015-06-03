//
//  UIFont+RMFont.h
//  Romo
//

#import <Foundation/Foundation.h>

@interface UIFont (RomoFonts)

+ (UIFont *)romoBoldFontWithSize:(float)size;
+ (UIFont *)romoFontWithSize:(float)size;
+ (UIFont *)voiceForRomoWithSize:(float)size;

+ (CGFloat)romoLargeFontSize;
+ (CGFloat)romoMediumFontSize;
+ (CGFloat)romoSmallFontSize;

+ (UIFont *)smallFont;
+ (UIFont *)mediumFont;
+ (UIFont *)largeFont;
+ (UIFont *)largerFont;
+ (UIFont *)hugeFont;
+ (UIFont *)fontWithSize:(CGFloat)size;

@end
