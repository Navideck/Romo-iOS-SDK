//
//  RMTouch.m
//  Poke
//

#import "RMTouch.h"
#import "UIView+Additions.h"
#import <Romo/RMMath.h>
#import <Romo/RMDispatchTimer.h>

@interface RMTouch ()

@property (nonatomic, strong) UIView *forehead;
@property (nonatomic, strong) UIView *rightEye;
@property (nonatomic, strong) UIView *leftEye;
@property (nonatomic, strong) UIView *nose;
@property (nonatomic, strong) UIView *chin;

@property (nonatomic) RMTouchLocation initialLocation;
@property (nonatomic) CGFloat distance;
@property (nonatomic) BOOL tickled;

/** Leak the distance for tickles over a second or so after tickling ends */
@property (nonatomic, strong) RMDispatchTimer *distanceLeak;

@end

static int minTickleDistance[5] = { 450, 320, 320, 110, 500 };

@implementation RMTouch

#pragma mark - Class Methods

+ (NSString *)nameForLocation:(RMTouchLocation)location
{
    switch (location) {
        case RMTouchLocationForehead: return @"forehead";
        case RMTouchLocationLeftEye: return @"left eye";
        case RMTouchLocationRightEye: return @"right eye";
        case RMTouchLocationNose: return @"nose";
        case RMTouchLocationChin: return @"chin";
        default: return nil;
    }
}

#pragma mark - Instance Methods

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.multipleTouchEnabled = NO;
        
        // Extend the height for taller iDevices
        CGFloat h = (frame.size.height - 480)/2;

        _forehead = [[UIView alloc] initWithFrame:CGRectMake(0, 0, frame.size.width, 120 + h)];
        self.forehead.backgroundColor = [UIColor clearColor];
        self.forehead.userInteractionEnabled = NO;
        self.forehead.tag = (int)RMTouchLocationForehead;
        [self addSubview:self.forehead];

        _nose = [[UIView alloc] initWithFrame:CGRectMake(90, 230 + h, 140, 70)];
        self.nose.backgroundColor = [UIColor clearColor];
        self.nose.layer.cornerRadius = 30;
        self.nose.userInteractionEnabled = NO;
        self.nose.tag = (int)RMTouchLocationNose;
        [self addSubview:self.nose];
        
        _rightEye = [[UIView alloc] initWithFrame:CGRectMake(41, 153 + h, 106, 106)];
        self.rightEye.backgroundColor = [UIColor clearColor];
        self.rightEye.layer.cornerRadius = 44;
        self.rightEye.userInteractionEnabled = NO;
        self.rightEye.tag = (int)RMTouchLocationRightEye;
        [self addSubview:self.rightEye];
        
        _leftEye = [[UIView alloc] initWithFrame:CGRectMake(171, 144 + h, 107, 115)];
        self.leftEye.backgroundColor = [UIColor clearColor];
        self.leftEye.layer.cornerRadius = 44;
        self.leftEye.userInteractionEnabled = NO;
        self.leftEye.tag = (int)RMTouchLocationLeftEye;
        [self addSubview:self.leftEye];
        
        _chin = [[UIView alloc] initWithFrame:CGRectMake(0, frame.size.height - 190 - h, frame.size.width, 190 + h)];
        self.chin.backgroundColor = [UIColor clearColor];
        self.chin.userInteractionEnabled = NO;
        self.chin.tag = (int)RMTouchLocationChin;
        [self addSubview:self.chin];
    }
    return self;
}

- (void)dealloc
{
    if (_distanceLeak) {
        [self.distanceLeak stopRunning];
    }
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    [self.distanceLeak stopRunning];
    
    CGPoint touchPoint = [[touches anyObject] locationInView:self];
    RMTouchLocation touchLocation = [self locationForPoint:touchPoint withEvent:event];
    
    if (touchLocation) {
        // If we're touching in a new location than the last time, reset tickle vars
        if (touchLocation != self.initialLocation) {
            self.initialLocation = touchLocation;
            self.distance = 0;
        } else {
            // Otherwise, increase the distance a bit to favor tickles with multiple swipes
            self.distance *= 1.5;
        }
        
        if (self.initialLocation && [self.delegate respondsToSelector:@selector(touch:beganPokingAtLocation:)]) {
            [self.delegate touch:self beganPokingAtLocation:self.initialLocation];
        }
    }
    
    if ([self.delegate respondsToSelector:@selector(touchesBegan:withEvent:)]) {
        [self.delegate touchesBegan:touches withEvent:event];
    }
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
    UITouch *touch = [touches anyObject];
    CGPoint touchPoint = [touch locationInView:self];
    RMTouchLocation touchLocation = [self locationForPoint:touchPoint withEvent:event];
    
    if (touchLocation && touchLocation == self.initialLocation) {
        CGPoint previousPoint = [touch previousLocationInView:self];
        self.distance += sqrtf(powf(touchPoint.x - previousPoint.x, 2) + powf(touchPoint.y - previousPoint.y, 2));

        if (!self.tickled && self.distance > minTickleDistance[touchLocation - 1]) {
            if ([self.delegate respondsToSelector:@selector(touch:cancelledPokingAtLocation:)]) {
                [self.delegate touch:self cancelledPokingAtLocation:touchLocation];
            }
            if ([self.delegate respondsToSelector:@selector(touch:detectedTickleAtLocation:)]) {
                [self.delegate touch:self detectedTickleAtLocation:touchLocation];
            }
            self.tickled = YES;
            self.distance = 0;
            self.initialLocation = 0;
        }
    } else if (!self.tickled) {
        if ([self.delegate respondsToSelector:@selector(touch:cancelledPokingAtLocation:)]) {
            [self.delegate touch:self cancelledPokingAtLocation:touchLocation];
        }
    }
    
    if ([self.delegate respondsToSelector:@selector(touchesMoved:withEvent:)]) {
        [self.delegate touchesMoved:touches withEvent:event];
    }
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    [self touchEnded:[touches anyObject]];
    
    if ([self.delegate respondsToSelector:@selector(touchesEnded:withEvent:)]) {
        [self.delegate touchesEnded:touches withEvent:event];
    }
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
    [self touchEnded:[touches anyObject]];
    
    if ([self.delegate respondsToSelector:@selector(touchesCancelled:withEvent:)]) {
        [self.delegate touchesCancelled:touches withEvent:event];
    }
}

#pragma mark - Private Methods

- (void)touchEnded:(UITouch *)touch
{
    if (!self.tickled && self.initialLocation) {
        if ([self.delegate respondsToSelector:@selector(touch:endedPokingAtLocation:)]) {
            [self.delegate touch:self endedPokingAtLocation:self.initialLocation];
        }

        [self.distanceLeak startRunning];
    } else if (self.tickled) {
        self.tickled = NO;
    }
}

- (RMTouchLocation)locationForPoint:(CGPoint)touchPoint withEvent:(UIEvent *)event;
{
    for (UIView *subview in self.subviews) {
        if (CGRectContainsPoint(subview.frame, touchPoint)) {
            return (RMTouchLocation)subview.tag;
        }
    }
    return 0;
}

- (RMDispatchTimer *)distanceLeak
{
    if (!_distanceLeak) {
        __weak RMTouch *weakSelf = self;
        
        _distanceLeak = [[RMDispatchTimer alloc] initWithName:@"com.Romotive.RomoTickleLeakyIntegrator" frequency:1.0 / 20.0];
        _distanceLeak.eventHandler = ^{
            if (weakSelf.distance > 10) {
                weakSelf.distance = 0.97 * weakSelf.distance;
            } else {
                weakSelf.distance = 0;
                weakSelf.initialLocation = 0;
                [weakSelf.distanceLeak stopRunning];
            }
        };
    }
    return _distanceLeak;
}

@end
