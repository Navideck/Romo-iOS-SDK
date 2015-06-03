//
//  RMControlInputMenu.h
//  Romo
//
//  Created on 9/6/13.
//  Copyright (c) 2013 Romotive. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface RMControlInputMenu : UIView

@property (nonatomic, readonly, strong) UIButton *dpadButton;
@property (nonatomic, readonly, strong) UIButton *joystickButton;
@property (nonatomic, readonly, strong) UIButton *tankButton;
@property (nonatomic, readonly, getter = isOpen) BOOL open;

- (CGSize)desiredSize;
- (void)openMenu;
- (void)closeMenu;

@end
