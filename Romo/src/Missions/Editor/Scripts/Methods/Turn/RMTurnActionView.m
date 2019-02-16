//
//  RMTurnActionView.m
//  Romo
//

#import "RMTurnActionView.h"
#import <QuartzCore/QuartzCore.h>
#import <Romo/RMMath.h>
#import "UIView+Additions.h"
#import "UIFont+RMFont.h"

static const float animationFrequency = 24.0;

static const float angleResolution = 15.0;
static const float minimumAngle = 15.0;
static const float maximumAngle = 360.0;

static const float radiusResolution = 2.5;
static const float minimumRadius = 0.0;
static const float maximumRadius = 20.0;

static const CGFloat radiusCmToPixels = 6.0;

static const CGFloat clockwiseButtonOffsetX = 42.0;

static const CGFloat animationCenterY = 132.0;

@interface RMTurnActionView ()

@property (nonatomic, strong) UIImageView *robot;

/** Animation of the turning robot */
@property (nonatomic, strong) dispatch_source_t animationTimer;
@property (nonatomic, getter=isAnimating) BOOL animating;
@property (nonatomic) CFAbsoluteTime previousStepTime;
@property (nonatomic) float animationAngle;
@property (nonatomic, strong) CAShapeLayer *arc;

/** Parameters */
@property (nonatomic) float angle;
@property (nonatomic) BOOL clockwise;
@property (nonatomic) float radius;

/** UI Inputs */
@property (nonatomic, strong) UISlider *angleSlider;
@property (nonatomic, strong) UISlider *radiusSlider;
@property (nonatomic, strong) UILabel *angleLabel;
@property (nonatomic, strong) UILabel *radiusLabel;
@property (nonatomic, strong) UIButton *clockwiseButton;
@property (nonatomic, strong) UIButton *counterClockwiseButton;

@end

@implementation RMTurnActionView

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        _robot = [[UIImageView alloc] initWithImage:[UIImage smartImageNamed:@"romoDriveForward1.png"]];
        self.robot.contentMode = UIViewContentModeCenter;
        self.robot.frame = CGRectMake(0, 0, 200, 200);
        self.robot.transform = CGAffineTransformMakeScale(0.55, 0.55);
        self.robot.center = CGPointMake(self.contentView.width / 2, self.contentView.height / 2 + 5);
        [self.contentView addSubview:self.robot];
    }
    return self;
}

- (void)dealloc
{
    [self stopAnimating];
}

- (void)startAnimating
{
    if (!self.isAnimating) {
        self.animating = YES;
        
        __weak RMTurnActionView *weakSelf = self;
        self.animationTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_queue_create("com.Romotive.Apple", 0));
        dispatch_source_set_timer(self.animationTimer, DISPATCH_TIME_NOW, NSEC_PER_SEC / animationFrequency, NSEC_PER_MSEC);
        dispatch_source_set_event_handler(self.animationTimer, ^{
            [weakSelf step];
        });
        
        dispatch_resume(self.animationTimer);
    }
}

- (void)stopAnimating
{
    if (self.isAnimating) {
        dispatch_source_cancel(self.animationTimer);
        self.animationTimer = nil;
        self.animating = NO;
    }
}

- (void)willLayoutForEditing:(BOOL)editing
{
    [super willLayoutForEditing:editing];
    
    if (editing) {
        self.angleSlider.centerY = self.contentView.height;
        self.angleSlider.alpha = 0.0;
        [self.contentView addSubview:self.angleSlider];
        
        self.angleLabel.centerY = self.angleSlider.centerY + 40;
        self.angleLabel.alpha = 0.0;
        [self.contentView addSubview:self.angleLabel];
        
        self.radiusSlider.centerY = self.angleLabel.centerY + 60;
        self.radiusSlider.alpha = 0.0;
        [self.contentView addSubview:self.radiusSlider];
        
        self.radiusLabel.centerY = self.radiusSlider.centerY + 40;
        self.radiusLabel.alpha = 0.0;
        [self.contentView addSubview:self.radiusLabel];
        
        self.clockwiseButton.center = CGPointMake(self.contentView.width / 2 + clockwiseButtonOffsetX, self.radiusLabel.centerY + 30);
        self.clockwiseButton.alpha = 0.0;
        [self.contentView addSubview:self.clockwiseButton];
        
        self.counterClockwiseButton.center = CGPointMake(self.contentView.width / 2 - clockwiseButtonOffsetX, self.clockwiseButton.centerY);
        self.counterClockwiseButton.alpha = 0.0;
        [self.contentView addSubview:self.counterClockwiseButton];
        
        self.angleSlider.value = self.angle;
        self.radiusSlider.value = self.radius;
    }
}

- (void)setEditing:(BOOL)editing
{
    super.editing = editing;
    
    self.clockwise = _clockwise;
    if (editing) {
        self.angleSlider.centerY = self.height / 2.0 + 22;
        self.angleLabel.top = self.angleSlider.bottom - 8;
        self.radiusSlider.top = self.angleLabel.bottom + 30;
        self.radiusLabel.top = self.radiusSlider.bottom - 8;
        self.clockwiseButton.center = CGPointMake(self.contentView.width / 2 + clockwiseButtonOffsetX, self.radiusLabel.bottom + 50);
        self.counterClockwiseButton.center = CGPointMake(self.contentView.width / 2 - clockwiseButtonOffsetX, self.clockwiseButton.centerY);
        
        self.angleSlider.alpha = 1.0;
        self.angleLabel.alpha = 1.0;
        self.radiusSlider.alpha = 1.0;
        self.radiusLabel.alpha = 1.0;
        self.clockwise = _clockwise;
    } else {
        self.angleSlider.alpha = 0.0;
        self.angleLabel.alpha = 0.0;
        self.radiusSlider.alpha = 0.0;
        self.radiusLabel.alpha = 0.0;
        self.clockwiseButton.alpha = 0.0;
        self.counterClockwiseButton.alpha = 0.0;
    }
}

- (void)didLayoutForEditing:(BOOL)editing
{
    [super didLayoutForEditing:editing];
    
    if (!editing) {
        [self.angleSlider removeFromSuperview];
        [self.angleLabel removeFromSuperview];
        [self.radiusSlider removeFromSuperview];
        [self.radiusLabel removeFromSuperview];
        [self.clockwiseButton removeFromSuperview];
        [self.counterClockwiseButton removeFromSuperview];
    }
}

- (void)setParameters:(NSArray *)parameters
{
    super.parameters = parameters;
    
    for (RMParameter *parameter in parameters) {
        if (parameter.type == RMParameterAngle) {
            self.angle = [parameter.value floatValue];
        } else if (parameter.type == RMParameterTurnDirection) {
            self.clockwise = [parameter.value boolValue];
        } else if (parameter.type == RMParameterRadius) {
            self.radius = [parameter.value floatValue];
        }
    }
}

#pragma mark - Private Methods

- (void)step
{
    CFAbsoluteTime currentTime = CACurrentMediaTime();
    if (self.previousStepTime) {
        float radianPerSecond = (9.0 * radiusCmToPixels) / (self.radius + 14);
        
        if (self.isAnimating) {
            CFAbsoluteTime dt = currentTime - self.previousStepTime;
            self.animationAngle += dt * radianPerSecond;
        } else {
            self.animationAngle = DEG2RAD(self.angle + 270);
        }
        
        CGFloat x = self.contentView.width / 2;
        CGFloat y = self.isEditing ? animationCenterY : self.contentView.height / 2 + 5;
        
        CGFloat editingScale = self.isEditing ? 1.0 : (0.55 / 0.65);
        CGFloat xRadius = editingScale * radiusCmToPixels * self.radius * (self.clockwise ? 1 : -1);
        CGFloat yRadius = editingScale * ABS(xRadius) / (self.isEditing ? 1.90 : 3.15);
        int imageNumber = 1 + (int)(_animationAngle / (2 * M_PI) * 42);
        
        dispatch_async(dispatch_get_main_queue(), ^{
            self.robot.center = CGPointMake(x - xRadius * sinf(self->_animationAngle), y + yRadius * cosf(self->_animationAngle));
            self.robot.image = [UIImage smartImageNamed:[NSString stringWithFormat:@"romoTurn%d.png",imageNumber]];
        });
    }
    self.previousStepTime = currentTime;
}

- (void)setAnimationAngle:(float)animationAngle
{
    _animationAngle = animationAngle > 2 * M_PI ? animationAngle - 2 * M_PI : animationAngle;
}

- (void)updateSubtitle
{
    self.title = [NSString stringWithFormat:NSLocalizedString(@"Turn-Action-Parameters-Title", @"Turn %@"), self.clockwise ? NSLocalizedString(@"Turn-Action-Parameters-Right", @"Right") : NSLocalizedString(@"Turn-Action-Parameters-Left", @"Left")];
    self.subtitle = [NSString stringWithFormat:NSLocalizedString(@"Turn-Action-Parameters-Subtitle", @"%d cm circle • %dº turn"), (int)(2 * self.radius), (int)self.angle];
}

- (void)setAngle:(float)angle
{
    angle = [RMMath round:angle toNearest:angleResolution];
    _angle = angle;
    
    for (RMParameter *parameter in self.parameters) {
        if (parameter.type == RMParameterAngle) {
            parameter.value = @(angle);
        }
    }
    [self updateSubtitle];
}

- (void)setClockwise:(BOOL)clockwise
{
    _clockwise = clockwise;
    self.animationAngle = (2 * M_PI) - self.animationAngle;
    self.angle = _angle;
    
    CGFloat scale = self.isEditing ? 0.65 : 0.55;
    if (clockwise) {
        self.robot.transform = CGAffineTransformMakeScale(scale, scale);
    } else {
        self.robot.transform = CGAffineTransformMakeScale(-scale, scale);
    }
    
    self.clockwiseButton.alpha = clockwise ? 1.0 : 0.45;
    self.counterClockwiseButton.alpha = !clockwise ? 1.0 : 0.45;
    
    for (RMParameter *parameter in self.parameters) {
        if (parameter.type == RMParameterTurnDirection) {
            parameter.value = @(clockwise);
        }
    }
    [self updateSubtitle];
}

- (void)setRadius:(float)radius
{
    radius = CLAMP(minimumRadius, [RMMath round:radius toNearest:radiusResolution], maximumRadius);
    _radius = radius;
    
    for (RMParameter *parameter in self.parameters) {
        if (parameter.type == RMParameterRadius) {
            parameter.value = @(radius);
        }
    }
    [self updateSubtitle];
}

- (void)angleSliderDidBeginDragging:(UISlider *)slider
{
    [self.contentView.layer insertSublayer:self.arc atIndex:0];
    [self updateArc];
    
    [self stopAnimating];
}

- (void)angleSliderDidEndDragging:(UISlider *)slider
{
    [self.arc removeFromSuperlayer];
    self.arc = nil;
    
    [self startAnimating];
}

- (void)angleSliderDidChangeValue:(UISlider *)slider
{
    self.angle = slider.value;
    [self updateArc];
}

- (void)radiusSliderDidBeginDragging:(UISlider *)slider
{
    [self.contentView.layer insertSublayer:self.arc atIndex:0];
    [self updateArc];
}

- (void)radiusSliderDidEndDragging:(UISlider *)slider
{
    [self.arc removeFromSuperlayer];
    self.arc = nil;
}

- (void)radiusSliderDidChangeValue:(UISlider *)slider
{
    self.radius = slider.value;
    [self updateArc];
}

- (void)handleClockwiseButtonTouch:(UIButton *)button
{
    self.clockwise = (button == self.clockwiseButton);
    [self updateArc];
}

- (void)updateArc
{
    [self step];
    
    CGFloat startX = self.contentView.width / 2;
    CGFloat startY = 0.0;
    
    CGFloat w = 28.0 + self.radius * 5.8;
    CGFloat angle = DEG2RAD(self.angle);
    
    CGMutablePathRef path = CGPathCreateMutable();
    if (self.clockwise) {
        CGPathMoveToPoint(path, nil, startX, startY);
        CGPathAddArc(path, nil, startX, startY, w, 0, angle, NO);
        CGPathAddLineToPoint(path, nil, startX, startY);
    } else {
        CGPathMoveToPoint(path, nil, startX, startY);
        CGPathAddArc(path, nil, startX, startY, w, M_PI, -angle + M_PI, YES);
        CGPathAddLineToPoint(path, nil, startX, startY);
    }
    self.arc.path = path;
    CGPathRelease(path);
}

#pragma mark - UI Properties

- (UISlider *)angleSlider
{
    if (!_angleSlider) {
        _angleSlider = [[UISlider alloc] initWithFrame:CGRectMake(15, 0, self.width - 30, 40)];
        _angleSlider.minimumValue = minimumAngle;
        _angleSlider.maximumValue = maximumAngle;
        _angleSlider.minimumTrackTintColor = [UIColor colorWithRed:1.0 green:0.38 blue:0.55 alpha:1.000];
        [_angleSlider addTarget:self action:@selector(angleSliderDidBeginDragging:) forControlEvents:UIControlEventTouchDown];
        [_angleSlider addTarget:self action:@selector(angleSliderDidEndDragging:) forControlEvents:UIControlEventTouchCancel | UIControlEventTouchUpInside | UIControlEventTouchUpOutside];
        [_angleSlider addTarget:self action:@selector(angleSliderDidChangeValue:) forControlEvents:UIControlEventValueChanged];
    }
    return _angleSlider;
}

- (UILabel *)angleLabel
{
    if (!_angleLabel) {
        _angleLabel = [[UILabel alloc] initWithFrame:CGRectMake(80, 0, self.width - 160, 24)];
        _angleLabel.text = NSLocalizedString(@"Angle", @"Angle");
        _angleLabel.backgroundColor = [UIColor clearColor];
        _angleLabel.textColor = [UIColor whiteColor];
        _angleLabel.font = [UIFont smallFont];
        _angleLabel.textAlignment = NSTextAlignmentCenter;
        _angleLabel.shadowColor = [UIColor colorWithWhite:0.0 alpha:0.4];
        _angleLabel.shadowOffset = CGSizeMake(0, -1);
    }
    return _angleLabel;
}

- (UISlider *)radiusSlider
{
    if (!_radiusSlider) {
        _radiusSlider = [[UISlider alloc] initWithFrame:CGRectMake(15, 0, self.width - 30, 40)];
        _radiusSlider.minimumValue = minimumRadius;
        _radiusSlider.maximumValue = maximumRadius;
        _radiusSlider.minimumTrackTintColor = [UIColor colorWithRed:1.0 green:0.38 blue:0.55 alpha:1.000];
        [_radiusSlider addTarget:self action:@selector(radiusSliderDidBeginDragging:) forControlEvents:UIControlEventTouchDown];
        [_radiusSlider addTarget:self action:@selector(radiusSliderDidEndDragging:) forControlEvents:UIControlEventTouchCancel | UIControlEventTouchUpInside | UIControlEventTouchUpOutside];
        [_radiusSlider addTarget:self action:@selector(radiusSliderDidChangeValue:) forControlEvents:UIControlEventValueChanged];
    }
    return _radiusSlider;
}

- (UILabel *)radiusLabel
{
    if (!_radiusLabel) {
        _radiusLabel = [[UILabel alloc] initWithFrame:CGRectMake(80, 0, self.width - 160, 24)];
        _radiusLabel.text = NSLocalizedString(@"Diameter", @"Diameter");
        _radiusLabel.backgroundColor = [UIColor clearColor];
        _radiusLabel.textColor = [UIColor whiteColor];
        _radiusLabel.font = [UIFont smallFont];
        _radiusLabel.textAlignment = NSTextAlignmentCenter;
        _radiusLabel.shadowColor = [UIColor colorWithWhite:0.0 alpha:0.4];
        _radiusLabel.shadowOffset = CGSizeMake(0, -1);
    }
    return _radiusLabel;
}

- (UIButton *)clockwiseButton
{
    if (!_clockwiseButton) {
        _clockwiseButton = [[UIButton alloc] initWithFrame:CGRectMake(0, 0, 64, 64)];
        [_clockwiseButton setImage:[UIImage imageNamed:@"turnClockwise.png"] forState:UIControlStateNormal];
        [_clockwiseButton setImage:[UIImage imageNamed:@"turnClockwise.png"] forState:UIControlStateHighlighted];
        _clockwiseButton.imageView.contentMode = UIViewContentModeCenter;
        [_clockwiseButton addTarget:self action:@selector(handleClockwiseButtonTouch:) forControlEvents:UIControlEventTouchDown];
    }
    return _clockwiseButton;
}

- (UIButton *)counterClockwiseButton
{
    if (!_counterClockwiseButton) {
        _counterClockwiseButton = [[UIButton alloc] initWithFrame:CGRectMake(0, 0, 64, 64)];
        _counterClockwiseButton.transform = CGAffineTransformMakeScale(-1.0, 1.0);
        [_counterClockwiseButton setImage:[UIImage imageNamed:@"turnClockwise.png"] forState:UIControlStateNormal];
        [_counterClockwiseButton setImage:[UIImage imageNamed:@"turnClockwise.png"] forState:UIControlStateHighlighted];
        _counterClockwiseButton.imageView.contentMode = UIViewContentModeCenter;
        [_counterClockwiseButton addTarget:self action:@selector(handleClockwiseButtonTouch:) forControlEvents:UIControlEventTouchDown];
    }
    return _counterClockwiseButton;
}

- (CAShapeLayer *)arc
{
    if (!_arc) {
        _arc = [CAShapeLayer layer];
        _arc.fillColor = [UIColor colorWithWhite:1.0 alpha:0.25].CGColor;
        _arc.transform = CATransform3DMakeScale(1.0, 1.0 / 1.88, 1.0);
        _arc.frame = CGRectMake(0, animationCenterY + 36.0, self.contentView.width, 120);
    }
    return _arc;
}

@end
