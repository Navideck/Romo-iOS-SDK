//
//  RUITelepresenceIncomingCallView.m
//  Romo3
//
//  Created on 5/6/13.
//  Copyright (c) 2013 Romotive. All rights reserved.
//

#import "RMTelepresenceIncomingCallView.h"
#import <QuartzCore/QuartzCore.h>

@implementation RMTelepresenceIncomingCallView

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    
    if (self) {
        self.backgroundColor = [UIColor blackColor];
        [self setupSubviews];
    }
    
    return self;
}

- (void)setupSubviews
{
    [self addSubview:self.characterView];
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    self.characterView.frame = self.bounds;
}


#pragma mark - UI Elements

- (UIView *)characterView
{
    if (_characterView == nil) {
        _characterView = [[UIView alloc] initWithFrame:CGRectZero];
    }
    
    return _characterView;
}

@end
