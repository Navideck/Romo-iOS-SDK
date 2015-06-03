//
//  UIAlertView+RMDismissAll.m
//  Romo
//
//  Created on 12/3/13.
//  Copyright (c) 2013 Romotive. All rights reserved.
//

#import "UIAlertView+RMDismissAll.h"

@implementation UIAlertView (RMDismissAll)

+ (void)dismissAll
{
    [self dismissAllInSubviews:[[UIApplication sharedApplication] windows]];
}

+ (void)dismissAllInSubviews:(NSArray *)subviews
{
    [subviews enumerateObjectsUsingBlock:^(id view, NSUInteger idx, BOOL *stop) {
        if ([view isKindOfClass:[UIAlertView class]]) {
            [(UIAlertView *)view dismissWithClickedButtonIndex:0 animated:NO];
        } else {
            [self dismissAllInSubviews:[view subviews]];
        }
    }];
}

@end
