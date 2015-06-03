//
//  RMCharacterColorFill.m
//  Wave
//

#import "RMCharacterColorFill.h"
#import <RMShared/RMShared.h>

/** Universally scales time (thus, speed) of the system */
static const float timeWarpFactor = 30.0;

/** The amplitude to oscillate around */
static const float baseAmplitude = 12.0;

/** The furthest distance from the base amplitude */
static const float maxAmplitudeScale = 5.0;

/** Rate of amplitude change; Higher is slower */
static const float amplitudeSpeedDivisor = 26.0;

static const float basePhaseChangeScale = 24.0;
static const float maxPhaseChangeScale = 6.0;
static const float phaseChangeSpeedDivisor = 30.0;

static const float baseCycleCount = 1.0;
static const float maxCycleScale = 0.001;
static const float cycleSpeedDivisor = 2000.0;

@interface RMCharacterColorFill ()

@property (nonatomic, strong) CAShapeLayer *fillShape;

@property (nonatomic) double startTime;

/** Wave properties */
@property (nonatomic) float amplitude;

@property (nonatomic) float cycles;

@property (nonatomic) float phase;

@end

@implementation RMCharacterColorFill

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [self.layer addSublayer:self.fillShape];
        
        _hasBackgroundFill = YES;
        
        self.startTime = currentTime();
        self.cycles = 1.0;
    }
    return self;
}

#pragma mark - Public Properties

- (void)setFillAmount:(float)fillAmount
{
    _fillAmount = fillAmount;
    
    if (self.hasBackgroundFill) {
        self.backgroundColor = [UIColor colorWithWhite:0.70 alpha:MIN(1.0, fillAmount * 1.5)];
    } else {
        self.backgroundColor = [UIColor clearColor];
    }
    
    if (fillAmount < 0.99) {
        double time = (currentTime() - self.startTime) * timeWarpFactor;
        
        // Randomize properties of the wave
        self.amplitude = baseAmplitude + maxAmplitudeScale * sinf(2.0 * M_PI * time / amplitudeSpeedDivisor);
        self.phase = time * basePhaseChangeScale + maxPhaseChangeScale * sinf(2.0 * M_PI * time / phaseChangeSpeedDivisor);
        self.cycles = baseCycleCount + maxCycleScale * sinf(2.0 * M_PI * time / cycleSpeedDivisor);
        
        CGFloat viewHeight = self.frame.size.height;
        CGFloat height = 1.2 * viewHeight * fillAmount;
        CGFloat top = viewHeight - height + 40.0;
        
        CGMutablePathRef fillPath = CGPathCreateMutable();
        CGPathMoveToPoint(fillPath, NULL, 0, top);
        
        if (self.frame.size.width > 0) {
            for (CGFloat x = 0; x <= self.frame.size.width; x++) {
                CGFloat y = top - self.amplitude * sinf(self.cycles * 2.0 * M_PI * (x - self.phase) / self.frame.size.width);
                CGPathAddLineToPoint(fillPath, NULL, x, y);
            }
        }
        
        CGPathAddLineToPoint(fillPath, NULL, self.frame.size.width, top);
        CGPathAddLineToPoint(fillPath, NULL, self.frame.size.width, viewHeight);
        CGPathAddLineToPoint(fillPath, NULL, 0, viewHeight);
        CGPathCloseSubpath(fillPath);
        
        self.fillShape.path = CGPathCreateCopy(fillPath);
    } else {
        self.fillShape.path = CGPathCreateWithRect(self.bounds, NULL);
    }
}

- (void)setFillColor:(UIColor *)fillColor
{
    _fillColor = fillColor;
    self.fillShape.fillColor = fillColor.CGColor;
}

#pragma mark - Private Properties

- (CAShapeLayer *)fillShape
{
    if (!_fillShape) {
        _fillShape = [CAShapeLayer layer];
    }
    return _fillShape;
}

@end
