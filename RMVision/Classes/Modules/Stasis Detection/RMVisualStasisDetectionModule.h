//
//  RMVisualStasisDetectionModule.h
//  RMVision
//
//  Created on 9/16/13.
//  Copyright (c) 2013 Romotive, Inc. All rights reserved.
//

#import "RMVisionModule.h"

@interface RMVisualStasisDetectionModule : RMVisionModule

@end


#ifdef VISUAL_STASIS_DEBUG
#import <UIKit/UIKit.h>

// Use UIWindow as a simple way to draw to the iDevice's screen
//
// NOTE:  UIView take a _very_ long time before it displays the first
//        time.  Backgrouding and then foregrounding the app will cause
//        it to appear immediately
@interface RMVisionDebugWindow : UIWindow

@property (nonatomic, strong) UIImageView *view;

- (void)displayWithImage:(UIImage*)image;

@end
#endif