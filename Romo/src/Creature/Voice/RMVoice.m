//
//  RMVoice.m
//  Romo
//
#import "RMVoice.h"
#import "UIView+Additions.h"
#import "UIFont+RMFont.h"
#import "UIColor+RMColor.h"
#import "UIImage+Tint.h"
#import "RMGradientLabel.h"

#define WORDS_PER_MINUTE 145

#define LARGE_TEXT_SIZE 48
#define SMALL_TEXT_SIZE 32

#ifdef DEBUG_ROMOSAY
#define LOG(...) DDLogWarn(__VA_ARGS__)
#else
#define LOG(...)
#endif //DEBUG_ROMOSAY

static const CGFloat buttonHeight = 54;
static const CGFloat leftButtonWidth = 142.0;
static const CGFloat rightButtonWidth = 178.0;

NSString *const RMVoiceUserDidSelectionOptionNotification = @"RMVoiceUserDidSelectionOptionNotification";

@interface RMVoice ()

@property (nonatomic, strong) NSMutableArray *labels;

@property (nonatomic) RMVoiceStyle presentationStyle;

@property (nonatomic) BOOL autoDismiss;
@property (nonatomic, strong) NSTimer *dismissTimer;

// Options
@property (nonatomic, strong) NSMutableArray *buttons;
@property (nonatomic, strong) UIImageView *backdrop;
@property (nonatomic, strong) UIImageView *divider;

/** Readwrite */
@property (nonatomic, readwrite) NSString* speech;
@property (nonatomic, readwrite, getter=isVisible) BOOL visible;
@property (nonatomic, readwrite) float duration;

@property (nonatomic, getter=isPresenting) BOOL presenting;
@property (nonatomic, getter=isDismissing) BOOL dismissing;

@property (nonatomic, copy) void (^presentingCompletion)(void);
@property (nonatomic, copy) void (^dismissingCompletion)(BOOL);

@end

@implementation RMVoice

+ (RMVoice *)voice
{
    return [[RMVoice alloc] initWithFrame:CGRectMake(0, 0, [UIScreen mainScreen].bounds.size.width, 0)];
}

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.autoDismiss = YES;
        self.userInteractionEnabled = NO;
    }
    return self;
}

- (void)say:(NSString *)speech
{
    [self say:speech withStyle:RMVoiceStyleSLS autoDismiss:YES];
}

- (void)say:(NSString *)speech withStyle:(RMVoiceStyle)style autoDismiss:(BOOL)autoDismiss
{
    LOG(@"(visible? %d dismissing? %d presenting? %d)\n%@", self.isVisible, self.isDismissing, self.isPresenting, speech);
    if (self.isVisible && !self.isDismissing) {
        // If we're already visible, dismiss first
        [self dismissWithCompletion:^(BOOL finished) {
            [self say:speech withStyle:style autoDismiss:autoDismiss];
        }];
    } else if (self.isDismissing) {
        // Otherwise, if we're animating, set the completion
        __weak RMVoice *weakSelf = self;
        self.dismissingCompletion = ^(BOOL finished){
            [weakSelf say:speech withStyle:style autoDismiss:autoDismiss];
        };
    } else {
        // Else, let's pop-in some speech
        self.presenting = YES;
        self.labels = nil;
        self.visible = YES;
        self.speech = speech;
        self.autoDismiss = autoDismiss;
        self.presentationStyle = style;
        [self.view addSubview:self];
        
#ifndef ROMO_CONTROL_APP
        if (self.character && !self.muteMumbleSound) {
            [self.character say:speech];
            self.muteMumbleSound = NO;
        }
#endif
        
        NSArray *lines = [speech componentsSeparatedByString:@"\n"];
        
        int i = 0;
        UILabel *previousLabel;
        for (NSString *line in lines) {
            // Use the presentation style as a bit-mask for each line's size
            CGFloat size = self.presentationStyle & 1 ? LARGE_TEXT_SIZE : SMALL_TEXT_SIZE;
            self.presentationStyle = self.presentationStyle >> 4;
            
            UILabel *label = [self labelWithText:line size:size];
            // accessibilityLabel is used by test frameworks to drive the app
            label.accessibilityLabel = [NSString stringWithFormat:@"Romo:%@", line];
            label.alpha = 0.0;
            [self addSubview:label];
            [self.labels addObject:label];
            
            label.origin = CGPointMake((self.width - label.width) / 2.0, previousLabel.bottom - 52);
            label.transform= CGAffineTransformMakeScale(0.1, 0.1);
            
            [UIView animateWithDuration:0.25 delay:0.2*i options:0
                             animations:^{
                                 label.alpha = 1.0;
                                 label.transform = CGAffineTransformMakeScale(1.1, 1.1);
                                 label.top += 48;
                             } completion:^(BOOL finished) {
                                 [UIView animateWithDuration:0.2
                                                  animations:^{
                                                      label.transform = CGAffineTransformIdentity;
                                                  } completion:^(BOOL finished) {
                                                      self.presenting = NO;
                                                      
                                                      if (self.presentingCompletion) {
                                                          void (^presentingCompletion)(void) = self.presentingCompletion;
                                                          self.presentingCompletion = nil;
                                                          presentingCompletion();
                                                      }
                                                  }];
                             }];
            
            
            previousLabel = label;
            i++;
        }
        
        self.height = previousLabel.bottom;
        self.centerY = self.superview.height - MAX(self.height / 2.0, 80);
        
        if (autoDismiss) {
            NSInteger numberOfWords = [speech componentsSeparatedByString:@" "].count;
            float timeInterval = 2.0 + numberOfWords / (WORDS_PER_MINUTE / 60.0);
            
            self.duration = timeInterval;
            self.dismissTimer = [NSTimer scheduledTimerWithTimeInterval:timeInterval target:self selector:@selector(dismiss) userInfo:nil repeats:NO];
        }
    }
}

- (void)ask:(NSString *)speech withAnswers:(NSArray *)answers
{
    [self dismissWithCompletion:^(BOOL finished) {
        self.userInteractionEnabled = YES;
        [self say:speech withStyle:RMVoiceStyleSSS autoDismiss:NO];
        
        CGFloat textHeight = self.height;
        self.height = textHeight + buttonHeight;
        self.bottom = self.superview.height;
        
        self.backdrop.width = self.width;
        self.backdrop.top = self.height;
        [self addSubview:self.backdrop];
        
        self.divider.left = leftButtonWidth;
        self.divider.top = self.height;
        [self addSubview:self.divider];
        
        NSInteger i = 0;
        for (NSString *answer in answers) {
            NSString *localizedAnswerOption = [[NSBundle mainBundle] localizedStringForKey:answer value:answer table:@"CharacterScripts"];
            UIButton *answerButton = [self buttonWithText:localizedAnswerOption emphasized:(i == 1)];
            answerButton.left = (i == 0) ? 0 : leftButtonWidth;
            answerButton.width = (i == 0) ? leftButtonWidth : rightButtonWidth;
            answerButton.top = self.height;
            answerButton.tag = i;
            [self addSubview:answerButton];
            [self.buttons addObject:answerButton];
            i++;
        }
        
        for (i = self.buttons.count - 1; i >= 0; i--) {
            UIButton *button = self.buttons[i];
            [UIView animateWithDuration:0.25 delay:0.5 options:0
                             animations:^{
                                 button.bottom = self.height;
                                 
                                 if (i == self.buttons.count - 1) {
                                     self.backdrop.bottom = self.height;
                                     self.divider.bottom = self.height;
                                 }
                             } completion:nil];
        }
    }];
}

- (void)dismiss
{
    [self dismissWithCompletion:nil];
}

- (void)dismissImmediately
{
    [self removeAllSubviews];
    [self.dismissTimer invalidate];
    self.speech = nil;
    self.visible = NO;
    self.autoDismiss = YES;
    self.duration = 0.0;
    self.labels = nil;
    self.dismissing = NO;
    self.presenting = NO;
    self.userInteractionEnabled = NO;
    self.dismissingCompletion = nil;
    self.presentingCompletion = nil;
    self.buttons = nil;
}

- (void)dismissWithCompletion:(void (^)(BOOL finished))completion
{
    LOG(@"");
    if (self.isPresenting) {
        // If we're in the middle of animating in, set this completion
        // to automatically animate out on completion
        __weak RMVoice *weakSelf = self;
        self.presentingCompletion = ^{
            [weakSelf dismissWithCompletion:completion];
        };
    } else if (!self.isVisible && !self.isDismissing) {
        // If we aren't shown, then we're already dismissed, so continue immediately
        if (completion) {
            completion(YES);
        }
    } else if (!self.isDismissing && self.visible && self.speech.length) {
        // Otherwise, animate out
        
        self.dismissing = YES;
        [self.dismissTimer invalidate];
        
        self.speech = nil;
        self.visible = NO;
        self.autoDismiss = YES;
        self.duration = 0.0;
        
        self.userInteractionEnabled = NO;
        
        // Pop out all labels
        NSInteger last = self.labels.count - 1;
        [self.labels enumerateObjectsUsingBlock:^(UILabel *label, NSUInteger index, BOOL *stop) {
            [UIView animateWithDuration:0.2 delay:0.2*index options:0
                             animations:^{
                                 label.transform = CGAffineTransformMakeScale(1.1, 1.1);
                             } completion:^(BOOL finished) {
                                 if (!self.visible) {
                                     [UIView animateWithDuration:0.25
                                                      animations:^{
                                                          label.transform = CGAffineTransformMakeScale(0.1, 0.1);
                                                          label.alpha = 0.0;
                                                      } completion:^(BOOL finished) {
                                                          if (index == last) {
                                                              self.dismissing = NO;
                                                              
                                                              if (!self.visible) {
                                                                  [self removeAllSubviews];
                                                                  self.labels = nil;
                                                              }
                                                              
                                                              if (completion) {
                                                                  completion(YES);
                                                              }
                                                              
                                                              if ([self.delegate respondsToSelector:@selector(speechDismissedForVoice:)]) {
                                                                  [self.delegate speechDismissedForVoice:self];
                                                              }
                                                              
                                                              if (self.dismissingCompletion) {
                                                                  void (^dismissingCompletion)(BOOL) = self.dismissingCompletion;
                                                                  self.dismissingCompletion = nil;
                                                                  dismissingCompletion(YES);
                                                              }
                                                          }
                                                      }];
                                 }
                             }];
        }];
        
        // Remove any options
        [UIView animateWithDuration:0.25
                         animations:^{
                             [self.buttons enumerateObjectsUsingBlock:^(UIButton *button, NSUInteger idx, BOOL *stop) {
                                 button.top = self.height;
                             }];
                             
                             self.backdrop.top = self.height;
                             self.divider.top = self.height;
                         } completion:^(BOOL finished) {
                             self.buttons = nil;
                             self.backdrop = nil;
                             self.divider = nil;
                         }];
    } else {
        self.dismissingCompletion = completion;
    }
}

- (void)userDidSelectAnswer:(UIButton *)answer
{
    [[NSNotificationCenter defaultCenter] postNotificationName:RMVoiceUserDidSelectionOptionNotification
                                                        object:self
                                                      userInfo:@{@"PresentedText": self.speech ? self.speech : @"-",
                                                                 @"SelectedOptionName": [answer titleForState:UIControlStateDisabled] ? [answer titleForState:UIControlStateDisabled] : @"-"}];
    
    if ([self.delegate respondsToSelector:@selector(userDidSelectOptionAtIndex:forVoice:)]) {
        [self.delegate userDidSelectOptionAtIndex:(int)answer.tag forVoice:self];
    }
}

- (NSMutableArray *)labels
{
    if (!_labels) {
        _labels = [NSMutableArray arrayWithCapacity:2];
    }
    return _labels;
}

- (NSMutableArray *)buttons
{
    if (!_buttons) {
        _buttons = [NSMutableArray arrayWithCapacity:2];
    }
    return _buttons;
}

- (UIImageView *)backdrop
{
    if (!_backdrop) {
        _backdrop = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"romoVoiceBackdrop.png"]];
    }
    return _backdrop;
}

- (UIImageView *)divider
{
    if (!_divider) {
        _divider = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"romoVoiceDivider.png"]];
    }
    return _divider;
}

- (UILabel *)labelWithText:(NSString *)text size:(float)size
{
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectZero];
    label.backgroundColor = [UIColor clearColor];
    label.font = [UIFont voiceForRomoWithSize:size];
    label.textColor = [UIColor romoWhite];
    label.textAlignment = NSTextAlignmentCenter;
    label.text = text;
    label.adjustsFontSizeToFitWidth = YES;
    label.minimumScaleFactor = 0.35;
    
    label.layer.shadowColor = [UIColor colorWithHue:0.686 saturation:1.0 brightness:0.44 alpha:1.0].CGColor;
    label.layer.shadowOffset = CGSizeMake(0, 2.5);
    label.layer.shadowOpacity = 0.2;
    label.layer.shadowRadius = 3.0;
    label.layer.shouldRasterize = YES;
    label.layer.rasterizationScale = 2.0;
    
    CGFloat actualFontSize;
    CGSize labelSize = [label.text sizeWithFont:label.font minFontSize:label.minimumScaleFactor * size
                                 actualFontSize:&actualFontSize forWidth:self.width - 36 lineBreakMode:label.lineBreakMode];
    label.height = [label.text sizeWithFont:[UIFont voiceForRomoWithSize:actualFontSize] constrainedToSize:CGSizeMake(self.width - 36, 2*size)].height;
    label.width = MIN(self.width - 36, labelSize.width);
    
    label.baselineAdjustment = UIBaselineAdjustmentAlignCenters;
    label.clipsToBounds = NO;
    
    return label;
}

- (UIButton *)buttonWithText:(NSString *)text emphasized:(BOOL)emphasized
{
    UIButton *button = [[UIButton alloc] initWithFrame:CGRectMake(0, 0, 160, buttonHeight)];
    [button addTarget:self action:@selector(userDidSelectAnswer:) forControlEvents:UIControlEventTouchUpInside];
    [button setTitle:[text uppercaseString] forState:UIControlStateNormal];
    [button setTitle:text forState:UIControlStateDisabled];
    button.titleLabel.font = [UIFont fontWithSize:18];
    button.layer.shadowOffset = CGSizeMake(0.0, 1.0);
    button.layer.shadowOpacity = 0.3;
    button.layer.shadowRadius = 1.0;
    button.layer.shadowColor = [UIColor colorWithHue:0.722 saturation:1.0 brightness:0.58 alpha:1.0].CGColor;
    
    if (emphasized) {
        // Tint the emphasized answer with a green gradient
        UIImage *greenGradient = [RMGradientLabel gradientImageForColor:[UIColor greenColor] label:button.titleLabel];
        UIColor *color = [UIColor colorWithPatternImage:greenGradient];
        UIColor *highlightedColor = [UIColor colorWithPatternImage:[greenGradient tintedImageWithColor:[UIColor colorWithWhite:1.0 alpha:0.5]]];
        [button setTitleColor:color forState:UIControlStateNormal];
        [button setTitleColor:highlightedColor forState:UIControlStateHighlighted];
    } else {
        // And the demphasized answer with a pale blue
        [button setTitleColor:[UIColor colorWithHue:0.536 saturation:0.80 brightness:1.0 alpha:1.0] forState:UIControlStateNormal];
        [button setTitleColor:[UIColor colorWithHue:0.536 saturation:0.20 brightness:1.0 alpha:1.0] forState:UIControlStateHighlighted];
    }
    
    return button;
}

@end
