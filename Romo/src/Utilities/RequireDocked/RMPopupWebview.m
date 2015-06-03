//
//  RMBuyRomoView.m
//  Romo
//
//  Created on 7/16/13.
//  Copyright (c) 2013 Romotive. All rights reserved.
//

#import "RMPopupWebview.h"

#import "UIButton+RMButtons.h"
#import "UIView+Additions.h"

@interface RMPopupWebview ()

@property (nonatomic, strong) UIWebView *webView;
@property (nonatomic, strong) UIButton *dismissButton;

@end

@implementation RMPopupWebview

#pragma mark -- Object lifecycle

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor blackColor];
        [self addSubview:self.webView];
        [self addSubview:self.dismissButton];
    }
    return self;
}

#pragma mark -- Layout

- (void)layoutSubviews
{
    [super layoutSubviews];
    self.webView.frame = self.bounds;
    self.dismissButton.origin = CGPointMake(10, 10);
}

#pragma mark -- Public properties

- (UIWebView *)webView
{
    if (!_webView) {
        _webView = [[UIWebView alloc] init];
        _webView.scrollView.bounces = NO;
        _webView.scalesPageToFit = YES;
    }
    
    return _webView;
}

- (UIButton *)dismissButton
{
    if (!_dismissButton) {
        _dismissButton = [UIButton backButtonWithImage:nil];
    }
    
    return _dismissButton;
}

@end
