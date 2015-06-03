//
//  RMVideoActionView.m
//  Romo
//

#import "RMVideoActionView.h"
#import <QuartzCore/QuartzCore.h>
#import "UIView+Additions.h"
#import "UIFont+RMFont.h"
#import "RMDurationInput.h"

@interface RMVideoActionView () <RMParameterInputDelegate>

/** iPhone & lens light */
@property (nonatomic, strong) UIImageView *iPhone;
@property (nonatomic, strong) UILabel *durationLabel;
@property (nonatomic, strong) UIImageView *lensGlow;

/** Duration in seconds of the video to be recorded */
@property (nonatomic) int duration;

/** Displayed when editing */
@property (nonatomic, strong) RMDurationInput *durationInput;

@end

@implementation RMVideoActionView

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        _iPhone = [[UIImageView alloc] initWithImage:[UIImage smartImageNamed:@"iphoneCamera.png"]];
        self.iPhone.centerX = self.contentView.width / 2;
        self.iPhone.bottom = self.contentView.height;
        [self.contentView addSubview:self.iPhone];

        _lensGlow = [[UIImageView alloc] initWithImage:[UIImage smartImageNamed:@"iphoneCameraGlow.png"]];
        self.lensGlow.center = CGPointMake(61, 31.5);
        self.lensGlow.alpha = 0.5;
        [self.iPhone addSubview:self.lensGlow];

        UIImageView *durationBackground = [[UIImageView alloc] initWithImage:[[UIImage smartImageNamed:@"iphoneCameraVideoTime.png"] resizableImageWithCapInsets:UIEdgeInsetsMake(0, 16, 0, 15)]];
        durationBackground.width = 50;
        durationBackground.center = CGPointMake(153, 73);
        durationBackground.alpha = 0.85;
        [self.iPhone addSubview:durationBackground];
    }
    return self;
}

- (void)willLayoutForEditing:(BOOL)editing
{
    [super willLayoutForEditing:editing];

    if (editing) {
        if (!self.durationInput) {
            self.durationInput = [[RMDurationInput alloc] initWithFrame:CGRectMake(0, 0, 210, 200)];
            self.durationInput.delegate = self;
            self.durationInput.centerX = self.width / 2;
        }
        self.durationInput.value = [NSString stringWithFormat:@"%@%d",self.duration < 10 ? @"0" : @"", self.duration];
        
        self.durationInput.centerY = [UIScreen mainScreen].bounds.size.height / 2.0 - 48.0;
        self.durationInput.alpha = 0.0;
        [self addSubview:self.durationInput];
    }
}

- (void)setEditing:(BOOL)editing
{
    super.editing = editing;
    
    if (editing) {
        self.iPhone.center = CGPointMake(self.contentView.width / 2.0, self.contentView.height - self.iPhone.height / 2.0);
        self.durationInput.alpha = 1.0;
    } else {
        self.iPhone.center = CGPointMake(self.contentView.width / 2.0, self.contentView.height - self.iPhone.height / 2.0);
        self.durationInput.alpha = 0.0;
    }
}

- (void)didLayoutForEditing:(BOOL)editing
{
    [super didLayoutForEditing:editing];
    
    if (!editing) {
        [self.durationInput removeFromSuperview];
        self.durationInput = nil;
    }
}

- (void)startAnimating
{
    CABasicAnimation* rotationAnimation = [CABasicAnimation animationWithKeyPath:@"transform.rotation.z"];
    rotationAnimation.toValue = @(M_PI * 2.0);
    rotationAnimation.duration = 3.0;
    rotationAnimation.cumulative = YES;
    rotationAnimation.repeatCount = INFINITY;
    [self.lensGlow.layer addAnimation:rotationAnimation forKey:@"rotationAnimation"];

    CABasicAnimation* alphaAnimation = [CABasicAnimation animationWithKeyPath:@"opacity"];
    alphaAnimation.toValue = @(1.0);
    alphaAnimation.duration = 0.8;
    alphaAnimation.autoreverses = YES;
    alphaAnimation.repeatCount = INFINITY;
    [self.lensGlow.layer addAnimation:alphaAnimation forKey:@"alphaAnimation"];
}

- (void)stopAnimating
{
    [self.lensGlow.layer removeAllAnimations];
}

- (void)setParameters:(NSArray *)parameters
{
    super.parameters = parameters;

    for (RMParameter *parameter in parameters) {
        if (parameter.type == RMParameterDuration) {
            self.duration = [parameter.value intValue];
        }
    }
}

#pragma mark - RMParameterInputDelegate

- (void)input:(RMParameterInput *)input didChangeValue:(id)value
{
    self.duration = [value intValue];
}

#pragma mark - Private Methods

- (void)setDuration:(int)duration
{
    _duration = duration;

    if (!self.durationLabel) {
        self.durationLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        self.durationLabel.backgroundColor = [UIColor clearColor];
        self.durationLabel.textColor = [UIColor whiteColor];
        self.durationLabel.font = [UIFont smallFont];
        self.durationLabel.textAlignment = NSTextAlignmentCenter;
        [self.iPhone addSubview:self.durationLabel];
    }

    self.durationLabel.text = [NSString stringWithFormat:@"0:%@%d",duration < 10 ? @"0" : @"",duration];
    self.durationLabel.size = [self.durationLabel.text sizeWithFont:self.durationLabel.font];
    self.durationLabel.center = CGPointMake(156, 73);

    for (RMParameter *parameter in self.parameters) {
        if (parameter.type == RMParameterDuration) {
            parameter.value = @(roundf(duration) + (duration - (roundf(duration)))/100.0);
        }
    }
}

@end
