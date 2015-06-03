//
//  UILabel+RomoStyles.h
//  Romo
//
//  Created on 12/2/13.
//  Copyright (c) 2013 Romotive. All rights reserved.
//

#import <UIKit/UIKit.h>

typedef enum {
    UILabelRomoStyleShadowed = 1 << 0,
    UILabelRomoStyleAlignmentCenter = 1 << 1,
    UILabelRomoStyleFontSizeLarge = 1 << 2,
    UILabelRomoStyleFontSizeMedium = 1 << 3,
    UILabelRomoStyleFontSizeLarger = 1 << 4
} UILabelRomoStyle;

@interface UILabel (RomoStyles)

+ (UILabel *)labelWithFrame:(CGRect)frame styleOptions:(UILabelRomoStyle)options;
+ (UILabel *)labelWithStyleOptions:(UILabelRomoStyle)options;

@end
