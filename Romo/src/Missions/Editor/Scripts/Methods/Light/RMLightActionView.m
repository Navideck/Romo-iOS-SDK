//
//  RMLightActionView
//  Romo
//

#import "RMLightActionView.h"
#import <QuartzCore/QuartzCore.h>
#import "UIView+Additions.h"
#import "UIFont+RMFont.h"

@interface RMLightActionView ()

@property (nonatomic, strong) UIImageView *robot;
@property (nonatomic, strong) UIImageView *light;
@property (nonatomic, strong) NSTimer *blinkTimer;

@property (nonatomic) float brightness;

/** shown when editing */
@property (nonatomic, strong) UISlider *brightnessSlider;
@property (nonatomic, strong) UILabel *brightnessLabel;

@end

@implementation RMLightActionView

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        _robot = [[UIImageView alloc] initWithImage:[UIImage smartImageNamed:@"romoLightOff.png"]];
        self.robot.centerX = self.contentView.width / 2;
        self.robot.top = 18;
        [self.contentView insertSubview:self.robot atIndex:0];
    }
    return self;
}

- (void)setTitle:(NSString *)title
{
    super.title = title;
    [self.contentView insertSubview:self.robot atIndex:0];
}

- (void)setState:(RMLightActionViewState)state
{
    [self stopAnimating];
    
    _state = state;
    switch (state) {
        case RMLightActionViewStateOff:
            [self.light removeFromSuperview];
            break;

        case RMLightActionViewStateBlink:
        default:
            if (!self.light) {
                self.light = [[UIImageView alloc] initWithImage:[UIImage smartImageNamed:@"romoLightOn.png"]];
                self.light.center = CGPointMake(self.robot.width / 2, 70);
                [self.robot addSubview:self.light];
            }
            break;
    }
}

- (void)setParameters:(NSArray *)parameters
{
    super.parameters = parameters;

    for (RMParameter *parameter in parameters) {
        if (parameter.type == RMParameterLightBrightness) {
            float brightness = [parameter.value floatValue];
            self.brightness = brightness;
            self.brightnessSlider.value = brightness;
        }
    }
}

- (void)willLayoutForEditing:(BOOL)editing
{
    [super willLayoutForEditing:editing];

    if (editing) {
        if (self.state == RMLightActionViewStateOn) {
            self.brightnessSlider.alpha = 0.0;
            [self.contentView addSubview:self.brightnessSlider];

            self.brightnessLabel.alpha = 0.0;
            [self.contentView addSubview:self.brightnessLabel];
        }
    }
}

- (void)setEditing:(BOOL)editing
{
    super.editing = editing;

    if (editing) {
        self.robot.center = CGPointMake(self.contentView.width / 2, self.contentView.height / 2 - 30);
        self.brightnessSlider.top = self.robot.bottom + 40;
        self.brightnessLabel.top = self.brightnessSlider.bottom - 8;
        
        self.brightnessSlider.alpha = 1.0;
        self.brightnessLabel.alpha = 1.0;
    } else {
        self.robot.center = CGPointMake(self.contentView.width / 2, 18 + self.robot.height / 2);
        self.brightnessSlider.top = self.contentView.height + 40;
        self.brightnessLabel.top = self.brightnessSlider.bottom - 8;
        
        self.brightnessSlider.alpha = 0.0;
        self.brightnessLabel.alpha = 0.0;
    }
}

- (void)startAnimating
{
    if (self.state == RMLightActionViewStateBlink) {
        [self.blinkTimer invalidate];
        self.blinkTimer = [NSTimer timerWithTimeInterval:0.35 target:self selector:@selector(animate) userInfo:nil repeats:YES];
        [[NSRunLoop currentRunLoop] addTimer:self.blinkTimer forMode:NSRunLoopCommonModes];
    }
}

- (void)stopAnimating
{
    [self.blinkTimer invalidate];
}

#pragma mark - Private Methods

- (void)animate
{
    self.light.hidden = !self.light.hidden;
}

- (void)setBrightness:(float)brightness
{
    _brightness = brightness;

    self.light.alpha = brightness / 100.0;

    for (RMParameter *parameter in self.parameters) {
        if (parameter.type == RMParameterLightBrightness) {
            parameter.value = @(brightness);
        }
    }

    self.subtitle = [NSString stringWithFormat:NSLocalizedString(@"LED-Action-Brightness-Unit", @"%d%% brightness"),(int)roundf(brightness)];
}

- (void)brightnessSliderDidChangeValue:(UISlider *)brightnessSlider
{
    self.brightness = brightnessSlider.value;
}

- (UISlider *)brightnessSlider
{
    if (!_brightnessSlider) {
        static const float minimumBrightness = 25.0; // %
        static const float maximumBrightness = 100.0; // %
        
        _brightnessSlider = [[UISlider alloc] initWithFrame:CGRectMake(20, self.contentView.height + 40, self.width - 40, 40)];
        _brightnessSlider.minimumValue = minimumBrightness;
        _brightnessSlider.maximumValue = maximumBrightness;
        _brightnessSlider.value = maximumBrightness;
        [_brightnessSlider addTarget:self action:@selector(brightnessSliderDidChangeValue:) forControlEvents:UIControlEventValueChanged];
        _brightnessSlider.minimumTrackTintColor = [UIColor colorWithRed:1.0 green:0.38 blue:0.55 alpha:1.000];
    }
    return _brightnessSlider;
}

- (UILabel *)brightnessLabel
{
    if (!_brightnessLabel) {
        _brightnessLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, self.brightnessSlider.bottom - 8, 0, 0)];
        _brightnessLabel.backgroundColor = [UIColor clearColor];
        _brightnessLabel.textColor = [UIColor whiteColor];
        _brightnessLabel.shadowColor = [UIColor colorWithWhite:0.0 alpha:0.4];
        _brightnessLabel.shadowOffset = CGSizeMake(0, -1);
        _brightnessLabel.font = [UIFont smallFont];
        _brightnessLabel.text = NSLocalizedString(@"LED-Action-Brightness-Label", @"Light Brightness");
        _brightnessLabel.size = [self.brightnessLabel.text sizeWithFont:self.brightnessLabel.font];
        _brightnessLabel.centerX = self.width / 2;
    }
    return _brightnessLabel;
}

@end
