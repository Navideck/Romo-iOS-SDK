//
//  RMControlDriveActionBar.h
//  Romo
//
//  Created on 9/4/13.
//  Copyright (c) 2013 Romotive. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface RMControlDriveActionBar : UIView

@property (nonatomic, strong) UIButton *cameraButton;
@property (nonatomic, strong) UIButton *photoRollButton;
@property (nonatomic, strong) UIButton *emotionButton;
@property (nonatomic, assign, getter = isWaitingForPicture) BOOL waitingForPicture;

- (CGFloat)desiredHeight;
- (void)pictureDidTimeOut;

@end
