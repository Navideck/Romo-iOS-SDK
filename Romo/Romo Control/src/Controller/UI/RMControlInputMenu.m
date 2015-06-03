//
//  RMControlInputMenu.m
//  Romo
//
//  Created on 9/6/13.
//  Copyright (c) 2013 Romotive. All rights reserved.
//

#import "RMControlInputMenu.h"
#import "UIView+Additions.h"

@interface RMControlInputMenu ()

// Public properties
@property (nonatomic, readwrite, strong) UIButton *dpadButton;
@property (nonatomic, readwrite, strong) UIButton *joystickButton;
@property (nonatomic, readwrite, strong) UIButton *tankButton;
@property (nonatomic, readwrite, getter = isOpen) BOOL open;

// Private properties
@property (nonatomic, strong) UIButton *showMenuButton;
@property (nonatomic, assign) CGFloat closedMenuHeight;

@end

@implementation RMControlInputMenu

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.open = NO;
        self.backgroundColor = [UIColor colorWithWhite:1 alpha:.35];
        
        [self addSubview:self.showMenuButton];
        [self addSubview:self.joystickButton];
        [self addSubview:self.tankButton];
        [self addSubview:self.dpadButton];
        
        self.joystickButton.alpha = 0;
        self.tankButton.alpha = 0;
        self.dpadButton.alpha = 0;
        
        [self.showMenuButton addTarget:self action:@selector(toggleMenu) forControlEvents:UIControlEventTouchUpInside];
    }
    return self;
}

- (void)layoutSubviews
{
    int optionButtonOffset = iPad ? 15 : 10;
    
    self.layer.cornerRadius = CGRectGetWidth(self.frame) / 2.0;
    
    self.showMenuButton.center = CGPointMake(CGRectGetMidX(self.bounds), self.showMenuButton.height / 2.0 - 4);
    self.joystickButton.center = CGPointMake(CGRectGetMidX(self.bounds), 83 + optionButtonOffset);
    self.tankButton.center = CGPointMake(CGRectGetMidX(self.bounds), 135 + optionButtonOffset);
    self.dpadButton.center = CGPointMake(CGRectGetMidX(self.bounds), 188 + optionButtonOffset);
}

- (CGSize)desiredSize
{
    return CGSizeMake(55, 55);
}

#pragma mark - Opening and closing control menu

- (void)toggleMenu
{
    if (self.isOpen) {
        [self closeMenu];
    } else {
        [self openMenu];
    }
}

- (void)openMenu
{
    if (!self.isOpen) {
        self.open = YES;
        self.closedMenuHeight = self.height;
        
        [UIView animateWithDuration:0.3 animations:^{
            self.height = self.dpadButton.bottom - 2;
        }];
        
        [self fadeInButton:self.joystickButton withDelay:0.1];
        [self fadeInButton:self.tankButton withDelay:0.15];
        [self fadeInButton:self.dpadButton withDelay:0.2];
        
        self.showMenuButton.selected = YES;
    }
}

- (void)closeMenu
{
    if (self.isOpen) {
        self.open = NO;
        
        [self fadeOutButton:self.dpadButton withDelay:0];
        [self fadeOutButton:self.tankButton withDelay:0.05];
        [self fadeOutButton:self.joystickButton withDelay:0.1];
        
        [UIView animateWithDuration:0.3 delay:0.05 options:0 animations:^{
            self.height = self.closedMenuHeight;
        } completion:nil];
        
        
        self.showMenuButton.selected = NO;
    }
}

- (void)fadeInButton:(UIButton *)button withDelay:(CGFloat)delay
{
    button.transform = CGAffineTransformMakeScale(.8, .8);
    [UIView animateWithDuration:0.15 delay:delay options:0 animations:^{
        button.alpha = 1;
        button.transform = CGAffineTransformMakeScale(1.05, 1.05);
    } completion:^(BOOL finished) {
        [UIView animateWithDuration:0.05 animations:^{
            button.transform = CGAffineTransformIdentity;
        }];
    }];
}

- (void)fadeOutButton:(UIButton *)button withDelay:(CGFloat)delay
{
    [UIView animateWithDuration:0.15 delay:delay options:0 animations:^{
        button.alpha = 0;
        button.transform = CGAffineTransformMakeScale(.8, .8);
    } completion:^(BOOL finished) {
        button.transform = CGAffineTransformIdentity;
    }];
}

#pragma mark - UI getters

- (UIButton *)showMenuButton
{
    if (_showMenuButton == nil) {
        _showMenuButton = [UIButton buttonWithType:UIButtonTypeCustom];
        _showMenuButton.frame = CGRectMake(0, 0, 64, 64);
        
        [_showMenuButton setImage:[UIImage imageNamed:@"drive-input-menu-settings"] forState:UIControlStateNormal];
        [_showMenuButton setImage:[UIImage imageNamed:@"drive-input-menu-settings-highlighted"] forState:UIControlStateHighlighted];
        [_showMenuButton setImage:[UIImage imageNamed:@"drive-input-menu-settings-highlighted"] forState:UIControlStateSelected];
    }
    return _showMenuButton;
}

- (UIButton *)joystickButton
{
    if (_joystickButton == nil) {
        _joystickButton = [UIButton buttonWithType:UIButtonTypeCustom];
        _joystickButton.frame = CGRectMake(0, 0, 64, 64);
        _joystickButton.clipsToBounds = NO;
        
        [_joystickButton setBackgroundImage:[UIImage imageNamed:@"drive-input-menu-joystick"] forState:UIControlStateNormal];
        [_joystickButton setImage:[UIImage imageNamed:@"drive-input-menu-joystick-highlighted"] forState:UIControlStateHighlighted];
        [_joystickButton setImage:[UIImage imageNamed:@"drive-input-menu-joystick-highlighted"] forState:UIControlStateSelected];
    }
    return _joystickButton;
}

- (UIButton *)tankButton
{
    if (_tankButton == nil) {
        _tankButton = [UIButton buttonWithType:UIButtonTypeCustom];
        _tankButton.frame = CGRectMake(0, 0, 64, 64);
        
        [_tankButton setImage:[UIImage imageNamed:@"drive-input-menu-tank"] forState:UIControlStateNormal];
        [_tankButton setImage:[UIImage imageNamed:@"drive-input-menu-tank-highlighted"] forState:UIControlStateHighlighted];
        [_tankButton setImage:[UIImage imageNamed:@"drive-input-menu-tank-highlighted"] forState:UIControlStateSelected];
    }
    return _tankButton;
}

-(UIButton *)dpadButton
{
    if (_dpadButton == nil) {
        _dpadButton = [UIButton buttonWithType:UIButtonTypeCustom];
        _dpadButton.frame = CGRectMake(0, 0, 64, 64);
        
        [_dpadButton setImage:[UIImage imageNamed:@"drive-input-menu-dpad"] forState:UIControlStateNormal];
        [_dpadButton setImage:[UIImage imageNamed:@"drive-input-menu-dpad-highlighted"] forState:UIControlStateHighlighted];
        [_dpadButton setImage:[UIImage imageNamed:@"drive-input-menu-dpad-highlighted"] forState:UIControlStateSelected];
    }
    return _dpadButton;
}

@end
