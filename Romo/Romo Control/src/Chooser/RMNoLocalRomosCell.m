//
//  RMNoLocalRomosCell.m
//  Romo
//
//  Created on 12/9/13.
//  Copyright (c) 2013 Romotive. All rights reserved.
//

#import "RMNoLocalRomosCell.h"
#import "UILabel+RomoStyles.h"
#import "UIView+Additions.h"

@interface RMNoLocalRomosCell ()

@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *bodyLabel;

@end

@implementation RMNoLocalRomosCell

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        _titleLabel = [UILabel labelWithStyleOptions:UILabelRomoStyleAlignmentCenter | UILabelRomoStyleFontSizeLarge | UILabelRomoStyleShadowed];
        
        _bodyLabel = [UILabel labelWithStyleOptions:UILabelRomoStyleAlignmentCenter | UILabelRomoStyleFontSizeMedium | UILabelRomoStyleShadowed];
        self.bodyLabel.lineBreakMode = NSLineBreakByWordWrapping;
        self.bodyLabel.numberOfLines = 0;
        
        self.titleLabel.text = NSLocalizedString(@"No Wi-Fi Romos are Available", nil);
        self.bodyLabel.text = NSLocalizedString(@"To control your Romo, connect another device to your WiFi and install the Romo app on that device.",nil);
        
        [self addSubview:self.titleLabel];
        [self addSubview:self.bodyLabel];
    }
    return self;
}

- (void)layoutSubviews
{
    self.titleLabel.size = [self.titleLabel sizeThatFits:CGSizeMake(self.width, CGFLOAT_MAX)];
    self.bodyLabel.size = [self.bodyLabel sizeThatFits:CGSizeMake(self.width - 60, CGFLOAT_MAX)];
    
    self.titleLabel.center = self.boundsCenter;
    self.bodyLabel.center = self.boundsCenter;
    
    if (iPad) {
        self.bodyLabel.top = self.bottom - self.bodyLabel.height - 160;
    }
    
    self.titleLabel.top = self.bodyLabel.top - self.titleLabel.height - 20;
}

@end
