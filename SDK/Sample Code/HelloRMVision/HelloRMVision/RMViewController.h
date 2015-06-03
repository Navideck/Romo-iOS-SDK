//
//  RMViewController.h
//  HelloRMVision
//
//  Created by Adam Setapen on 6/16/13.
//  Copyright (c) 2013 Romotive, Inc. All rights reserved.
//

#import <UIKit/UIKit.h>

#import <RMVision/RMVision.h>

@interface RMViewController : UIViewController <RMVisionDelegate>

@property (nonatomic, strong) RMVision *vision;

@end
