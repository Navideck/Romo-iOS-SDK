//
//  RMDriveActionView.m
//  Romo
//

#import "RMDriveActionView.h"
#import <QuartzCore/QuartzCore.h>
#import "UIView+Additions.h"
#import "UIFont+RMFont.h"
#import "RMParameter.h"
#import <Romo/RMMath.h>

static const float minimumDriveSpeed = 20.0;
static const float maximumDriveSpeed = 100.0;
static const float driveSpeedResolution = 5.0;

static const float minimumDriveDistance = 5.0;
static const float maximumDriveDistance = 100.0;
static const float driveDistanceResolution = 5.0;

/** Drive speeds higher than this force us to scale down the UI */
static const float maximumDriveSpeedBeforeScalingUI = 30.0;

static const float robotWidth = 140.0;
static const float robotLeft = 12.0;
static const float robotDistancePixelScale = 24.0;
static const float ghostLeft = 32.0;
static const float ghostCropPixels = 55.0;

@interface RMDriveActionView ()

@property (nonatomic, strong) UIImageView *robot;

@property (nonatomic) float distance;
@property (nonatomic) float speed;

@property (nonatomic) float pixelsPerSecond;
@property (nonatomic, strong) NSTimer *stepTimer;
@property (nonatomic) CFAbsoluteTime previousStepTime;

@property (nonatomic, strong) UIView *ghostRomos;

@property (nonatomic, strong) UISlider *speedSlider;
@property (nonatomic, strong) UISlider *distanceSlider;
@property (nonatomic, strong) UILabel *speedLabel;
@property (nonatomic, strong) UILabel *distanceLabel;

@end

@implementation RMDriveActionView

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {                
        _robot = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"romoDriveForward1.png"]];
        self.robot.animationImages = @[
                                       [UIImage imageNamed:@"romoDriveForward1.png"],
                                       [UIImage imageNamed:@"romoDriveForward2.png"],
                                       [UIImage imageNamed:@"romoDriveForward3.png"],
                                       [UIImage imageNamed:@"romoDriveForward4.png"],
                                       ];
        self.robot.animationRepeatCount = 0;
        self.robot.frame = CGRectMake(robotWidth, 14, 115.5, 120);
        [self.contentView addSubview:self.robot];
    }
    return self;
}

- (void)startAnimating
{
    [self.stepTimer invalidate];
    
    [self.robot startAnimating];
    self.stepTimer = [NSTimer timerWithTimeInterval:1.0/30.0 target:self selector:@selector(step) userInfo:nil repeats:YES];
    [[NSRunLoop currentRunLoop] addTimer:self.stepTimer forMode:NSRunLoopCommonModes];
}

- (void)stopAnimating
{
    [self.stepTimer invalidate];
    [self.robot stopAnimating];
    self.previousStepTime = 0;
}

- (void)willLayoutForEditing:(BOOL)editing
{
    [super willLayoutForEditing:editing];

    if (editing) {
        [self buildEditingLayout];
        self.speedSlider.alpha = 0.0;
        self.speedLabel.alpha = 0.0;
        self.distanceSlider.alpha = 0.0;
        self.distanceLabel.alpha = 0.0;
    }

    [self stopAnimating];
}

- (void)setEditing:(BOOL)editing
{
    super.editing = editing;

    if (editing) {
        self.robot.centerY = self.contentView.height / 2;
        self.distanceSlider.alpha = 1.0;
        self.distanceLabel.alpha = 1.0;
        self.speedSlider.alpha = 1.0;
        self.speedLabel.alpha = 1.0;

        self.distanceSlider.centerY = self.robot.bottom + 40;
        self.distanceLabel.top = self.distanceSlider.bottom - 8;
        self.speedSlider.top = self.distanceLabel.bottom + 30;
        self.speedLabel.top = self.speedSlider.bottom - 8;

        self.ghostRomos.left = ghostLeft;

    } else {
        self.robot.top = 4;
        self.distanceSlider.alpha = 0.0;
        self.distanceLabel.alpha = 0.0;
        self.speedSlider.alpha = 0.0;
        self.speedLabel.alpha = 0.0;

        self.distanceSlider.centerY = self.contentView.height + 60;
        self.distanceLabel.top = self.distanceSlider.bottom - 8;
        self.speedSlider.top = self.distanceLabel.bottom + 30;
        self.speedLabel.top = self.speedSlider.bottom - 8;
    }
}

- (void)didLayoutForEditing:(BOOL)editing
{
    [super didLayoutForEditing:editing];

    if (editing) {
        self.ghostRomos.top = self.robot.top;
    } else {
        [self.speedSlider removeFromSuperview];
        [self.distanceSlider removeFromSuperview];
        [self.speedLabel removeFromSuperview];
        [self.distanceLabel removeFromSuperview];
    }

    [self startAnimating];
}

- (void)setParameters:(NSArray *)parameters
{
    super.parameters = parameters;

    for (RMParameter *parameter in parameters) {
        if (parameter.type == RMParameterSpeed) {
            self.speed = [parameter.value floatValue];
        } else if (parameter.type == RMParameterDistance) {
            self.distance = [parameter.value floatValue];
        }
    }
}

#pragma mark - Private Methods

- (void)step
{
    CFAbsoluteTime currentTime = CACurrentMediaTime();
    if (self.previousStepTime) {
        CFAbsoluteTime dt = currentTime - self.previousStepTime;
        if (_forward) {
            if (_robot.left < self.width - 8) {
                _robot.left += _pixelsPerSecond * dt;
            } else {
                _robot.left = -130;
            }
        } else {
            if (_robot.left > -130) {
                _robot.left -= _pixelsPerSecond * dt;
            } else {
                _robot.left = self.width - 8;
            }            
        }
    }
    self.previousStepTime = currentTime;
}

- (void)setSpeed:(float)speed
{
    if (speed != _speed) {
        _speed = speed;

        float roundedSpeed = [RMMath round:speed toNearest:driveSpeedResolution];
        for (RMParameter *parameter in self.parameters) {
            if (parameter.type == RMParameterSpeed) {
                parameter.value = @(roundedSpeed);
            }
        }

        const float robotLengthPixels = 120.0; // Romo thumb in pixels
        const float robotLengthCm = 14.0; // Romo's length in cm
        const float topSpeed = 0.75; // Romo's top speed in m/s
        const float pixelsPerMeter = robotLengthPixels / robotLengthCm * 100.0;
        
        self.pixelsPerSecond = (pixelsPerMeter * topSpeed * speed) / 100.0;
        
        float duration = MAX(0.1, self.width / (self.pixelsPerSecond * 20.0));
        if (self.robot.animationDuration != duration) {
            self.robot.animationDuration = duration;
            [self.robot startAnimating];
        }

        [self updateSubtitle];
    }
}

- (void)setDistance:(float)distance
{
    if (distance != _distance) {
        _distance = distance;
        
       float roundedDistance = [RMMath round:distance toNearest:driveDistanceResolution];
        for (RMParameter *parameter in self.parameters) {
            if (parameter.type == RMParameterDistance) {
                parameter.value = @(roundedDistance);
            }
        }
        
        [self updateSubtitle];
    }
}

- (void)updateSubtitle
{
    float roundedSpeed = [RMMath round:self.speed toNearest:driveSpeedResolution];
    float roundedDistance = [RMMath round:self.distance toNearest:driveDistanceResolution];
    
    self.subtitle = [NSString stringWithFormat:@"%.0f cm • %.0f%% %@", roundedDistance, roundedSpeed, NSLocalizedString(@"Speed", @"Speed")];
}

- (void)speedSliderDidChangeValue:(UISlider *)slider
{
    self.speed = slider.value;
}

- (void)distanceSliderDidBeginDragging:(UISlider *)slider
{
    [self stopAnimating];

    [self.contentView insertSubview:self.ghostRomos atIndex:0];
    [self distanceSliderDidChangeValue:slider];
}

- (void)distanceSliderDidEndDragging:(UISlider *)slider
{
    double delayInSeconds = 0.35;
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
        if (!slider.isHighlighted) {
            [self.ghostRomos removeFromSuperview];
            
            self.previousStepTime = CACurrentMediaTime();
            [self startAnimating];
        }
    });
}

- (void)distanceSliderDidChangeValue:(UISlider *)slider
{
    self.distance = slider.value;

    float distance = slider.value;
    float width = (self.contentView.width - (2 * robotLeft) - robotWidth);

    int frame = (self.forward ? (1 + (int)(distance) % 4) : (4 - (int)(distance) % 4));
    self.robot.image = [UIImage smartImageNamed:[NSString stringWithFormat:@"romoDriveForward%d.png",frame]];

    if (distance <= maximumDriveSpeedBeforeScalingUI) {
        CGFloat left = robotLeft + width * (distance / robotDistancePixelScale);
        if (self.forward) {
            self.robot.left = left;
            self.ghostRomos.left = ghostLeft;
            self.ghostRomos.width = left - ghostLeft + ghostCropPixels;
        } else {
            self.robot.right = self.contentView.width - left;
            self.ghostRomos.right = self.contentView.width - ghostLeft;
            self.ghostRomos.width = (self.contentView.width - ghostLeft) - self.robot.right + ghostCropPixels;
        }
    } else {
        CGFloat left = robotLeft + width * (maximumDriveSpeedBeforeScalingUI / robotDistancePixelScale);
        if (self.forward) {
            self.robot.left = left;
            self.ghostRomos.left = ghostLeft - width * ((distance - maximumDriveSpeedBeforeScalingUI) / robotDistancePixelScale);
            self.ghostRomos.width = left - self.ghostRomos.left + ghostCropPixels;
        } else {
            self.robot.right = self.contentView.width - left;
            self.ghostRomos.right = (self.contentView.width - ghostLeft) + width * ((distance - maximumDriveSpeedBeforeScalingUI) / robotDistancePixelScale);
            self.ghostRomos.width = (self.width - self.robot.right) - ghostLeft + ghostCropPixels;
        }
    }
}

- (void)setForward:(BOOL)forward
{
    _forward = forward;
    
    if (forward) {
        self.title = @"Drive Forward";
        self.robot.animationImages = @[
                                       [UIImage smartImageNamed:@"romoDriveForward1.png"],
                                       [UIImage smartImageNamed:@"romoDriveForward2.png"],
                                       [UIImage smartImageNamed:@"romoDriveForward3.png"],
                                       [UIImage smartImageNamed:@"romoDriveForward4.png"],
                                       ];
    } else {
        self.title = @"Drive Backward";
        self.robot.animationImages = @[
                                       [UIImage smartImageNamed:@"romoDriveForward4.png"],
                                       [UIImage smartImageNamed:@"romoDriveForward3.png"],
                                       [UIImage smartImageNamed:@"romoDriveForward2.png"],
                                       [UIImage smartImageNamed:@"romoDriveForward1.png"],
                                       ];
    }
}

- (void)buildEditingLayout
{
    if (!self.distanceSlider) {
        self.distanceSlider = [[UISlider alloc] initWithFrame:CGRectMake(15, self.contentView.height + 40, self.width - 30, 40)];
        self.distanceSlider.minimumValue = minimumDriveDistance;
        self.distanceSlider.maximumValue = maximumDriveDistance;
        self.distanceSlider.value = self.distance;
        self.distanceSlider.minimumTrackTintColor = [UIColor colorWithRed:1.0 green:0.38 blue:0.55 alpha:1.000];

        [self.distanceSlider addTarget:self action:@selector(distanceSliderDidBeginDragging:) forControlEvents:UIControlEventTouchDown];
        [self.distanceSlider addTarget:self action:@selector(distanceSliderDidEndDragging:) forControlEvents:UIControlEventTouchCancel | UIControlEventTouchUpInside | UIControlEventTouchUpOutside];
        [self.distanceSlider addTarget:self action:@selector(distanceSliderDidChangeValue:) forControlEvents:UIControlEventValueChanged];
    }
    [self.contentView addSubview:self.distanceSlider];

    if (!self.distanceLabel) {
        self.distanceLabel = [[UILabel alloc] initWithFrame:CGRectMake(80, self.speedSlider.bottom - 8, self.width - 160, 24)];
        self.distanceLabel.text = NSLocalizedString(@"Distance", @"Distance");
        self.distanceLabel.backgroundColor = [UIColor clearColor];
        self.distanceLabel.textColor = [UIColor whiteColor];
        self.distanceLabel.font = [UIFont smallFont];
        self.distanceLabel.textAlignment = NSTextAlignmentCenter;
        self.distanceLabel.shadowColor = [UIColor colorWithWhite:0.0 alpha:0.4];
        self.distanceLabel.shadowOffset = CGSizeMake(0, -1);
    }
    [self.contentView addSubview:self.distanceLabel];

    if (!self.speedSlider) {
        self.speedSlider = [[UISlider alloc] initWithFrame:CGRectMake(15, self.speedLabel.bottom + 40, self.width - 30, 40)];
        [self.speedSlider addTarget:self action:@selector(speedSliderDidChangeValue:) forControlEvents:UIControlEventValueChanged];
        self.speedSlider.minimumValue = minimumDriveSpeed;
        self.speedSlider.maximumValue = maximumDriveSpeed;
        self.speedSlider.value = self.speed;
        self.speedSlider.minimumTrackTintColor = [UIColor colorWithRed:1.0 green:0.38 blue:0.55 alpha:1.000];
    }
    [self.contentView addSubview:self.speedSlider];

    if (!self.speedLabel) {
        self.speedLabel = [[UILabel alloc] initWithFrame:CGRectMake(80, self.distanceSlider.bottom - 8, self.width - 160, 24)];
        self.speedLabel.text = NSLocalizedString(@"Speed", @"Speed");
        self.speedLabel.backgroundColor = [UIColor clearColor];
        self.speedLabel.textColor = [UIColor whiteColor];
        self.speedLabel.font = [UIFont smallFont];
        self.speedLabel.textAlignment = NSTextAlignmentCenter;
        self.speedLabel.shadowColor = [UIColor colorWithWhite:0.0 alpha:0.4];
        self.speedLabel.shadowOffset = CGSizeMake(0, -1);
    }
    [self.contentView addSubview:self.speedLabel];

    if (!self.ghostRomos) {
        self.ghostRomos = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 0, 115)];
        self.ghostRomos.backgroundColor = [UIColor colorWithPatternImage:[UIImage smartImageNamed:@"romoDriveGhost.png"]];
        self.ghostRomos.alpha = 0.35;

        if (self.forward) {
            self.ghostRomos.contentMode = UIViewContentModeLeft;
        } else {
            self.ghostRomos.contentMode = UIViewContentModeRight;
        }
    }
}

@end
