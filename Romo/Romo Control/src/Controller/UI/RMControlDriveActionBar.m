//
//  RMControlDriveActionBar.m
//  Romo
//
//  Created on 9/4/13.
//  Copyright (c) 2013 Romotive. All rights reserved.
//

#import "RMControlDriveActionBar.h"

@interface RMControlDriveActionBar ()

@property (nonatomic, strong) UIImageView *background;

@end

@implementation RMControlDriveActionBar

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [self addSubview:self.background];
        [self addSubview:self.cameraButton];
        [self addSubview:self.photoRollButton];
        [self addSubview:self.emotionButton];
    }
    return self;
}

- (void)layoutSubviews
{
    self.background.frame = CGRectMake(0, 0, CGRectGetMaxX(self.bounds), CGRectGetHeight(self.background.frame));
    
    if (iPad) {
        self.cameraButton.center = CGPointMake(CGRectGetMidX(self.bounds), CGRectGetMidY(self.bounds) - 2);
        self.photoRollButton.center = CGPointMake(CGRectGetMidX(self.bounds) - 120, CGRectGetMidY(self.bounds) + 15);
        self.emotionButton.center = CGPointMake(CGRectGetMidX(self.bounds) + 120, CGRectGetMidY(self.bounds) + 15);
    } else {
        self.cameraButton.center = CGPointMake(CGRectGetMidX(self.bounds), CGRectGetMidY(self.bounds) + 2);
        self.photoRollButton.center = CGPointMake(CGRectGetMidX(self.bounds) - 80, CGRectGetMidY(self.bounds) + 9);
        self.emotionButton.center = CGPointMake(CGRectGetMidX(self.bounds) + 80, CGRectGetMidY(self.bounds) + 9);
    }
}

- (CGFloat)desiredHeight
{
    return CGRectGetHeight(self.background.frame);
}

#pragma mark - Updating camera button

- (void)setWaitingForPicture:(BOOL)waitingForPicture
{
    [self.cameraButton setEnabled:!waitingForPicture];
    _waitingForPicture = waitingForPicture;
}

- (void)pictureDidTimeOut
{
    self.waitingForPicture = NO;
}

#pragma mark - View Getters

- (UIImageView *)background
{
    if (_background == nil) {
        _background = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"console-bg"]];
    }
    return _background;
}

- (UIButton *)cameraButton
{
    if (_cameraButton == nil) {
        _cameraButton = [UIButton buttonWithType:UIButtonTypeCustom];
        
        if (iPad) {
            _cameraButton.frame = CGRectMake(0, 0, 87, 87);
        } else {
            _cameraButton.frame = CGRectMake(0, 0, 60, 60);
        }
        
        [_cameraButton setImage:[UIImage imageNamed:@"camera"] forState:UIControlStateNormal];
    }
    return _cameraButton;
}

- (UIButton *)photoRollButton
{
    if (_photoRollButton == nil) {
        _photoRollButton = [UIButton buttonWithType:UIButtonTypeCustom];
        _photoRollButton.frame = CGRectMake(0, 0, 44, 44);
        [_photoRollButton setImage:[UIImage imageNamed:@"photo-roll-button"] forState:UIControlStateNormal];
    }
    return _photoRollButton;
}


- (UIButton *)emotionButton
{
    if (_emotionButton == nil) {
        _emotionButton = [UIButton buttonWithType:UIButtonTypeCustom];
        _emotionButton.frame = CGRectMake(0, 0, 44, 44);
        [_emotionButton setImage:[UIImage imageNamed:@"emotion-button"] forState:UIControlStateNormal];
    }
    return _emotionButton;
}

@end
