//
//  RMWifiToolbar.m
//  Romo
//
//  Created on 12/2/13.
//  Copyright (c) 2013 Romotive. All rights reserved.
//

#import "RMWifiToolbar.h"
#import "UIView+Additions.h"
#import "UILabel+RomoStyles.h"

@interface RMWifiToolbar ()

@property (nonatomic, strong) UIImageView *wifiIcon;
@property (nonatomic, strong) UILabel *titleLabel;

@end

@implementation RMWifiToolbar

+ (CGFloat)preferredHeight
{
    UIImage *image = [UIImage imageNamed:@"missionsTopBarBackground"];
    return image.size.height;
}

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor colorWithPatternImage:[UIImage imageNamed:@"missionsTopBarBackground"]];
        
        _wifiIcon = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"wifiSelectionIcon"]];
        [self addSubview:self.wifiIcon];
        
        _titleLabel = [UILabel labelWithStyleOptions:UILabelRomoStyleAlignmentCenter | UILabelRomoStyleFontSizeMedium];
        self.titleLabel.text = @"Hello";
        [self addSubview:self.titleLabel];
    }
    return self;
}

- (void)layoutSubviews
{
    self.titleLabel.frame = CGRectMake(0, 0, self.width, 18);
    self.titleLabel.center = CGPointMake(self.width / 2.0, (self.height / 2.0) + self.titleLabel.height / 2.0);
    
    self.wifiIcon.center = CGPointMake(self.width / 2.0, (self.height / 2.0) - self.wifiIcon.height);
}

#pragma mark - Setting the title text

- (void)setTitleText:(NSString *)text
{
    self.titleLabel.text = text;
}

@end
