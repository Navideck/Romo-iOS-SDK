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
//  RUIBorderView.m
//  RMVision
//
//  Created on 4/3/13.
//  Copyright (c) 2013 Romotive. All rights reserved.
//
////////////////////////////////////////////////////////////////////////////////
#import "RMBorderView.h"

#import <QuartzCore/QuartzCore.h>

@interface RMBorderView ()

@property float lastRotation;

@end

@implementation RMBorderView

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
        self.rotation = 0;
        self.lastRotation = 0;
        self.fillColor = [UIColor colorWithWhite:1.000 alpha:0.160];
    }
    return self;
}

- (void)drawRect:(CGRect)rect
{
    if (self.label && self.strokeColor) {
        UIBezierPath *rrect = [UIBezierPath bezierPathWithRoundedRect:self.location cornerRadius:5.0];
        [self.strokeColor setStroke];
        [self.fillColor setFill];
        rrect.lineWidth = 4.0;
        CGFloat rrectPattern[] = {1, 1, 1, 1};
        [rrect setLineDash:rrectPattern count:4 phase:0];
        
        [rrect stroke];
        [rrect fill];
        
        [self.strokeColor setFill];
        [self.label drawInRect:CGRectInset(self.location, 4, 0) withFont:[UIFont boldSystemFontOfSize:18.0]];

//        self.center = CGPointMake(CGRectGetMidX(self.location), CGRectGetMidY(self.location));
//        CGAffineTransform rot = CGAffineTransformMakeRotation(DEG2RAD(self.rotation));
//        self.transform = rot;
    }
}



@end
