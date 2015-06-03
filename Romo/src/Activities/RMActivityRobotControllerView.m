//
//  RMActivityRobotControllerView.m
//  Romo
//

#import "RMActivityRobotControllerView.h"
#import "UIView+Additions.h"
#import "UIColor+RMColor.h"
#import "UIFont+RMFont.h"

static const CGFloat titleLabelCenterY = 32.0;

static const CGFloat spaceButtonSize = 64.0;
static const CGFloat spaceButtonPaddingUL = 16.0;
static const CGFloat spaceButtonPaddingBR = 12.0;
static const CGFloat spaceButtonIconOffsetY = 4.0;

static const CGFloat helpButtonSize = 64.0;
static const CGFloat helpButtonPaddingUR = 16.0;
static const CGFloat helpButtonPaddingBL = 20.0;

static const float popAnimationDuration = 0.15;

@interface RMActivityRobotControllerView ()

/** Planets icon inside space button */
@property (nonatomic, strong) UIImageView *spaceButtonIcon;

/** "?" icon inside help button */
@property (nonatomic, strong) UIImageView *helpButtonIcon;

/** Readonly */
@property (nonatomic, strong, readwrite) UILabel *titleLabel;
@property (nonatomic, strong, readwrite) UIButton *spaceButton;
@property (nonatomic, strong, readwrite) UIButton *helpButton;
@property (nonatomic, readwrite, getter=isAnimating) BOOL animating;

@end

@implementation RMActivityRobotControllerView

#pragma mark - Layout

- (void)layoutSubviews
{
    if (CGAffineTransformEqualToTransform(self.titleLabel.transform, CGAffineTransformIdentity)) {
        self.titleLabel.size = [self.titleLabel.text sizeWithFont:self.titleLabel.font];
    }
    self.titleLabel.center = CGPointMake(self.width / 2.0, titleLabelCenterY);
    
    // Positioned in the upper corners
    // Note: we align the center, not origin, because at times we apply transforms to the buttons
    self.helpButton.center = CGPointMake(spaceButtonSize / 2.0, spaceButtonSize / 2.0);
    self.helpButton.center = CGPointMake(self.width - helpButtonSize / 2.0, helpButtonSize / 2.0);
}

#pragma mark - Public Methods

- (void)layoutForAttentive
{
    [self animateInUI];
}

- (void)layoutForInattentive
{
    [self animateOutUI];
}

#pragma mark - Public Properties

- (UILabel *)titleLabel
{
    if (!_titleLabel) {
        _titleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _titleLabel.backgroundColor = [UIColor clearColor];
        _titleLabel.textColor = [UIColor colorWithHue:0.536 saturation:0.5 brightness:1.0 alpha:1.0];
        _titleLabel.font = [UIFont mediumFont];
        _titleLabel.textAlignment = NSTextAlignmentCenter;
    }
    return _titleLabel;
}

- (UIButton *)spaceButton
{
    if (!self.showsSpaceButton) {
        return nil;
    }
    
    if (!_spaceButton) {
        _spaceButton = [[UIButton alloc] initWithFrame:CGRectMake(0, 0, spaceButtonSize, spaceButtonSize)];
        _spaceButton.imageEdgeInsets = UIEdgeInsetsMake(spaceButtonPaddingUL, spaceButtonPaddingUL, spaceButtonPaddingBR - 1, spaceButtonPaddingBR);
        [_spaceButton setImage:[UIImage imageNamed:@"spaceButtonBg.png"] forState:UIControlStateNormal];
    }
    return _spaceButton;
}

- (UIButton *)helpButton
{
    if (!self.showsHelpButton) {
        return nil;
    }
    
    if (!_helpButton) {
        _helpButton = [[UIButton alloc] initWithFrame:CGRectMake(0, 0, helpButtonSize, helpButtonSize)];
        _helpButton.imageEdgeInsets = UIEdgeInsetsMake(helpButtonPaddingUR, helpButtonPaddingBL, helpButtonPaddingBL - 1, helpButtonPaddingUR);
        [_helpButton setImage:[UIImage imageNamed:@"helpButtonBg.png"] forState:UIControlStateNormal];
        _helpButton.accessibilityLabel = NSLocalizedString(@"Help-Button-Accessibility-Label", @"Help Button");
        _helpButton.isAccessibilityElement = YES;
    }
    return _helpButton;
}

- (void)setShowsSpaceButton:(BOOL)showsSpaceButton
{
    _showsSpaceButton = showsSpaceButton;
    if (_spaceButton.superview) {
        [self.spaceButton removeFromSuperview];
        self.spaceButton = nil;
    }
}

- (void)setShowsHelpButton:(BOOL)showsHelpButton
{
    _showsHelpButton = showsHelpButton;
    if (_helpButton.superview) {
        [self.helpButton removeFromSuperview];
        self.helpButton = nil;
    }
}

#pragma mark - Private Properties

- (UIImageView *)spaceButtonIcon
{
    if (!_spaceButtonIcon) {
        _spaceButtonIcon = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"spaceButtonIcon.png"]];
    }
    return _spaceButtonIcon;
}

- (UIImageView *)helpButtonIcon
{
    if (!_helpButtonIcon) {
        _helpButtonIcon = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"helpButtonIcon.png"]];
    }
    return _helpButtonIcon;
}

#pragma mark - Animation

- (void)animateInUI
{
    self.animating = YES;
    [self addSubview:self.titleLabel];
    [UIView animateWithDuration:popAnimationDuration delay:0.0 options:UIViewAnimationOptionCurveEaseOut
                     animations:^{
                         self.titleLabel.transform = CGAffineTransformMakeScale(1.2, 1.2);
                     } completion:^(BOOL finished) {
                         [self animateInSpaceButton];
                         [UIView animateWithDuration:popAnimationDuration
                                          animations:^{
                                              self.titleLabel.transform = CGAffineTransformIdentity;
                                          } completion:^(BOOL finished) {
                                              [self animateInHelpButton];
                                          }];
                     }];
}

- (void)animateOutUI
{
    self.animating = YES;
    [UIView animateWithDuration:popAnimationDuration
                     animations:^{
                         self.helpButton.transform = CGAffineTransformMakeScale(1.2, 1.2);
                     } completion:^(BOOL finished) {
                         [UIView animateWithDuration:popAnimationDuration
                                          animations:^{
                                              self.helpButton.transform = CGAffineTransformMakeScale(0.25, 0.25);
                                              self.spaceButton.transform = CGAffineTransformMakeScale(1.2, 1.2);
                                          } completion:^(BOOL finished) {
                                              [self.helpButton removeFromSuperview];
                                              [self.helpButtonIcon removeFromSuperview];
                                              [UIView animateWithDuration:popAnimationDuration
                                                               animations:^{
                                                                   self.spaceButton.transform = CGAffineTransformMakeScale(0.25, 0.25);
                                                                   self.titleLabel.transform = CGAffineTransformMakeScale(1.1, 1.1);
                                                               } completion:^(BOOL finished) {
                                                                   [self.spaceButton removeFromSuperview];
                                                                   [self.spaceButtonIcon removeFromSuperview];
                                                                   [UIView animateWithDuration:popAnimationDuration
                                                                                    animations:^{
                                                                                        self.titleLabel.transform = CGAffineTransformMakeScale(0.25, 0.25);
                                                                                        self.titleLabel.alpha = 0.0;
                                                                                    } completion:^(BOOL finished) {
                                                                                        [self.titleLabel removeFromSuperview];
                                                                                        self.titleLabel = nil;
                                                                                        self.animating = NO;
                                                                                    }];
                                                               }];
                                          }];
                     }];
}

- (void)animateInSpaceButton
{
    [self addSubview:self.spaceButton];
    [UIView animateWithDuration:popAnimationDuration delay:0.0 options:UIViewAnimationOptionCurveEaseOut
                     animations:^{
                         self.spaceButton.transform = CGAffineTransformMakeScale(1.3, 1.3);
                     } completion:^(BOOL finished) {
                         [UIView animateWithDuration:popAnimationDuration
                                          animations:^{
                                              self.spaceButton.transform = CGAffineTransformIdentity;
                                          } completion:^(BOOL finished) {
                                              self.spaceButtonIcon.center = CGPointMake((spaceButtonSize + spaceButtonPaddingUL - spaceButtonPaddingBR) / 2.0,
                                                                                        (spaceButtonSize - spaceButtonPaddingUL + spaceButtonPaddingBR) / 2.0 + spaceButtonIconOffsetY);
                                              self.spaceButtonIcon.transform = CGAffineTransformMakeScale(0.5, 0.5);
                                              [self.spaceButton addSubview:self.spaceButtonIcon];
                                              [UIView animateWithDuration:popAnimationDuration delay:0.0 options:UIViewAnimationOptionCurveEaseOut
                                                               animations:^{
                                                                   self.spaceButtonIcon.transform = CGAffineTransformMakeScale(1.3, 1.3);
                                                               } completion:^(BOOL finished) {
                                                                   [UIView animateWithDuration:popAnimationDuration
                                                                                    animations:^{
                                                                                        self.spaceButtonIcon.transform = CGAffineTransformIdentity;
                                                                                    }];
                                                               }];
                                              
                                          }];
                     }];
}

- (void)animateInHelpButton
{
    [self addSubview:self.helpButton];
    [UIView animateWithDuration:popAnimationDuration delay:0.0 options:UIViewAnimationOptionCurveEaseOut
                     animations:^{
                         self.helpButton.transform = CGAffineTransformMakeScale(1.3, 1.3);
                     } completion:^(BOOL finished) {
                         [UIView animateWithDuration:popAnimationDuration
                                          animations:^{
                                              self.helpButton.transform = CGAffineTransformIdentity;
                                          } completion:^(BOOL finished) {
                                              self.helpButtonIcon.center = CGPointMake((helpButtonSize + helpButtonPaddingBL - helpButtonPaddingUR) / 2.0,
                                                                                       (helpButtonSize - helpButtonPaddingBL + helpButtonPaddingUR) / 2.0);
                                              self.helpButtonIcon.transform = CGAffineTransformMakeScale(0.5, 0.5);
                                              [self.helpButton addSubview:self.helpButtonIcon];
                                              [UIView animateWithDuration:popAnimationDuration delay:0.0 options:UIViewAnimationOptionCurveEaseOut
                                                               animations:^{
                                                                   self.helpButtonIcon.transform = CGAffineTransformMakeScale(1.3, 1.3);
                                                               } completion:^(BOOL finished) {
                                                                   [UIView animateWithDuration:popAnimationDuration
                                                                                    animations:^{
                                                                                        self.helpButtonIcon.transform = CGAffineTransformIdentity;
                                                                                    } completion:^(BOOL finished) {
                                                                                        self.animating = NO;
                                                                                    }];
                                                               }];
                                              
                                          }];
                     }];
}

@end
