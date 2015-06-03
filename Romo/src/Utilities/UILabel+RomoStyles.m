//
//  UILabel+RomoStyles.m
//  Romo
//
//  Created on 12/2/13.
//  Copyright (c) 2013 Romotive. All rights reserved.
//

#import "UILabel+RomoStyles.h"
#import "UIFont+RMFont.h"

@implementation UILabel (RomoStyles)

+ (UILabel *)labelWithFrame:(CGRect)frame styleOptions:(UILabelRomoStyle)options
{
    UILabel *label = [self labelWithStyleOptions:options];
    label.frame = frame;
    return label;
}

+ (UILabel *)labelWithStyleOptions:(UILabelRomoStyle)options
{
    UILabel *label = [[UILabel alloc] init];
    label.backgroundColor = [UIColor clearColor];
    label.textColor = [UIColor whiteColor];
    
    if (options & UILabelRomoStyleShadowed) {
        label.layer.shadowColor = [UIColor colorWithHue:0.65 saturation:0.85 brightness:0.35 alpha:1.0].CGColor;
        label.layer.shadowOffset = CGSizeMake(0.0, 1.5);
        label.layer.shadowOpacity = 1.0;
        label.layer.shadowRadius = 1.0;
        label.layer.rasterizationScale = 2.0;
        label.layer.shouldRasterize = YES;
    }
    
    if (options & UILabelRomoStyleAlignmentCenter) {
        label.textAlignment = NSTextAlignmentCenter;
    }
    
    if (options & UILabelRomoStyleFontSizeLarger) {
        label.font = [UIFont largerFont];
    } else if (options & UILabelRomoStyleFontSizeLarge) {
        label.font = [UIFont largeFont];
    } else if (options & UILabelRomoStyleFontSizeMedium) {
        label.font = [UIFont mediumFont];
    }
    
    return label;
}

@end
