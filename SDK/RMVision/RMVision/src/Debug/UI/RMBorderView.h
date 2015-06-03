////////////////////////////////////////////////////////////////////////////////
//                             _
//                            | | (_)
//   _ __ ___  _ __ ___   ___ | |_ ___   _____
//  | '__/ _ \| '_ ` _ \ / _ \| __| \ \ / / _ \
//  | | | (_) | | | | | | (_) | |_| |\ V /  __/
//  |_|  \___/|_| |_| |_|\___/ \__|_| \_/ \___|
//
////////////////////////////////////////////////////////////////////////////////
//
//  RUIBorderView.h
//  RMVision
//
//  Created by Romotive on 4/3/13.
//  Copyright (c) 2013 Romotive. All rights reserved.
//
////////////////////////////////////////////////////////////////////////////////
#import <UIKit/UIKit.h>

@interface RMBorderView : UIView

@property (atomic) CGRect location;
@property (atomic) NSString *label;
@property (atomic) UIColor *strokeColor;
@property (atomic) UIColor *fillColor;

@property (atomic) float rotation;

@end
