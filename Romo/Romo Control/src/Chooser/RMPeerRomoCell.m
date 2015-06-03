//
//  RMPeerRomoCell.m
//  Romo
//
//  Created on 11/25/13.
//  Copyright (c) 2013 Romotive. All rights reserved.
//

#import "RMPeerRomoCell.h"
#import "UIFont+RMFont.h"
#import "UIView+Additions.h"
#import "UILabel+RomoStyles.h"

static const UILabelRomoStyle kCenterShadowedMediumLabelStyle = UILabelRomoStyleAlignmentCenter
                                                              | UILabelRomoStyleShadowed
                                                              | UILabelRomoStyleFontSizeMedium;

@interface RMPeerRomoCell ()

@property (nonatomic, strong) UILabel *romoNameLabel;

@end

@implementation RMPeerRomoCell

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.romoNameLabel = [UILabel labelWithStyleOptions:kCenterShadowedMediumLabelStyle];
        [self addSubview:self.romoNameLabel];
        
        self.romoImageView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"romoteRomo.png"]];
        [self addSubview:self.romoImageView];
    }
    return self;
}

- (void)prepareForReuse
{
    self.data = nil;
    self.romoNameLabel.text = @"";
}

- (void)update
{
    if (iPad) {
        self.romoImageView.center = CGPointMake(self.boundsCenter.x, self.boundsCenter.y + 260);
    } else {
        self.romoImageView.center = CGPointMake(self.boundsCenter.x, self.bottom - (self.romoImageView.height / 2.0) - 44);
    }
    
    self.romoNameLabel.frame = CGRectMake(0, 0, self.width - 60, 34);
    self.romoNameLabel.center = CGPointMake(self.romoImageView.center.x, self.romoImageView.center.y + (self.romoImageView.height / 2.0));
    
    self.romoNameLabel.text = [self labelText];
}

- (NSString *)labelText
{
    return @"";
}

@end
