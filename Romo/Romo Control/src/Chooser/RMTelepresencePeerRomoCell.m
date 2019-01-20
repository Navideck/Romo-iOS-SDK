//
//  RMTelepresencePeerRomoCell.m
//  Romo
//
//  Created on 11/25/13.
//  Copyright (c) 2013 Romotive. All rights reserved.
//

#import "RMTelepresencePeerRomoCell.h"
#import "RMContact.h"
#import "UIView+Additions.h"

@interface RMTelepresencePeerRomoCell ()

@property (nonatomic, strong) RMContact *data;

@end

@implementation RMTelepresencePeerRomoCell

@dynamic data;

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [self addSubview:self.deleteButton];
    }
    return self;
}

- (NSString *)labelText
{
    return [NSString stringWithFormat:NSLocalizedString(@"Remote: %@", @"Remote: %@"), self.data.romoName];
}

- (UIButton *)deleteButton
{
    if (!_deleteButton) {
        _deleteButton = [UIButton buttonWithType:UIButtonTypeCustom];
        _deleteButton.frame = CGRectMake(0, 0, 40, 40);
        _deleteButton.centerX = self.boundsCenter.x;
        [_deleteButton setImage:[UIImage imageNamed:@"actionViewDeleteButton"] forState:UIControlStateNormal];
        _deleteButton.hidden = YES;
    }
    return _deleteButton;
}

- (void)update
{
    [super update];
    _deleteButton.bottom = self.romoImageView.top - 5;
}

@end
