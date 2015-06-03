//
//  UIFont+RMFont.m
//  Romo
//

#import "UIFont+RMFont.h"

@implementation UIFont (RMFont)

+ (UIFont *)voiceForRomoWithSize:(float)size
{
    NSString *fontName;
    // For Japanese language, the default font is thin
    // so SODC requests that we use a different font for
    // Romo's speech in JA
    NSString *language = [[NSLocale preferredLanguages] objectAtIndex:0];
    if ([language isEqualToString:@"ja"]) {
        fontName = @"HiraKakuProN-W6";
    } else {
        fontName = @"Chewy";
    }
    return [UIFont fontWithName:fontName size:size];
}

+ (UIFont *)romoBoldFontWithSize:(float)size
{
    return [UIFont boldSystemFontOfSize:size];
}

+ (UIFont *)romoFontWithSize:(float)size
{
    return [UIFont systemFontOfSize:size];
}

+ (CGFloat)romoLargeFontSize
{
    return 19.f;
}

+ (CGFloat)romoMediumFontSize
{
    return 18.f;
}

+ (CGFloat)romoSmallFontSize
{
    return 16.f;
}

+ (UIFont *)smallFont
{
    return [self fontWithSize:14];
}

+ (UIFont *)mediumFont
{
    return [self fontWithSize:20];
}

+ (UIFont *)largeFont
{
    return [self fontWithSize:26];
}

+ (UIFont *)largerFont
{
    return [self fontWithSize:36];
}

+ (UIFont *)hugeFont
{
    return [self fontWithSize:76];
}

+ (UIFont *)fontWithSize:(CGFloat)size
{
    return [UIFont fontWithName:@"Chewy" size:size];
}

@end
