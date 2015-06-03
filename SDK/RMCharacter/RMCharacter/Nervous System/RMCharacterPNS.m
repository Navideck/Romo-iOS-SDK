//
//  RMCharacterPNS.m
//  RMCharacter
//

#import "RMCharacterPNS.h"
#import "RMMath.h"

#define doubleBlinkPercentage 28.0

static const CGFloat blinkMu       = 6.0;
static const CGFloat blinkSigma    = 4.0;
static const BOOL    blinkEnable   = YES;

static const CGFloat lookMu        = 15.0;
static const CGFloat lookSigma     = 4.0;
static const BOOL    lookEnable    = YES;

static const CGFloat breatheMu     = 10.0;
static const CGFloat breatheSigma  = 2.0;
static const BOOL    breatheEnable = NO;

@interface RMCharacterPNS () {
    NSTimer *_blinkTimer;
    NSTimer *_lookTimer;
    NSTimer *_breatheTimer;
    
    NSTimeInterval _blinkTimeInterval;
    NSTimeInterval _lookTimeInterval;
    NSTimeInterval _breatheTimeInterval;
}

- (void) triggerBlink:(NSTimer *)timer;
- (void) triggerLook:(NSTimer *)timer;
- (void) triggerBreathe:(NSTimer *)timer;

@end

@implementation RMCharacterPNS

#pragma mark - Initialization --

- (id)init
{
    self = [super init];
    if (self) {
        [self reset];
    }
    return self;
}

- (void)reset
{
    [self stop];
    
    [self _resetBlink];
    [self _resetLook];
    [self _resetBreathe];
}

- (void)stop
{
    [_blinkTimer invalidate];
    [_lookTimer invalidate];
    [_breatheTimer invalidate];
}

#pragma mark - Trigger events --

- (void)triggerBlink:(NSTimer *)timer
{
    dispatch_async(dispatch_get_main_queue(), ^(void){
        if (arc4random() % 100 < doubleBlinkPercentage) {
            [self.delegate didRecievePNSSignalWithType:RMCharacterPNSSignalDoubleBlink];
        } else {
            [self.delegate didRecievePNSSignalWithType:RMCharacterPNSSignalBlink];
        }
    });
    
    [self _resetBlink];
}

- (void)triggerLook:(NSTimer *)timer
{
    dispatch_async(dispatch_get_main_queue(), ^(void){
        [self.delegate didRecievePNSSignalWithType:RMCharacterPNSSignalLook];
    });
    
    [self _resetLook];
}

- (void)triggerBreathe:(NSTimer *)timer
{
    dispatch_async(dispatch_get_main_queue(), ^(void){
        [self.delegate didRecievePNSSignalWithType:RMCharacterPNSSignalBreathe];
    });
    
    [self _resetBreathe];
}

#pragma mark - Reset timers --

- (void)_resetBlink
{
    if (blinkEnable) {
        [_blinkTimer invalidate];
		_blinkTimeInterval = [RMMath drawFromNormal:blinkMu stdDev:blinkSigma];
		_blinkTimer = [NSTimer scheduledTimerWithTimeInterval:_blinkTimeInterval target:self selector:@selector(triggerBlink:) userInfo:nil repeats:NO];
	}
}

- (void)_resetLook
{
    if (lookEnable) {
        _lookTimeInterval = [RMMath drawFromNormal:lookMu stdDev:lookSigma];
        _lookTimer = [NSTimer scheduledTimerWithTimeInterval:_lookTimeInterval target:self selector:@selector(triggerLook:) userInfo:nil repeats:NO];
    }
}

- (void)_resetBreathe
{
    if (breatheEnable) {
        _breatheTimeInterval = [RMMath drawFromNormal:breatheMu stdDev:breatheSigma];
        _breatheTimer = [NSTimer scheduledTimerWithTimeInterval:_breatheTimeInterval target:self selector:@selector(triggerBreathe:) userInfo:nil repeats:NO];
    }
}
@end
