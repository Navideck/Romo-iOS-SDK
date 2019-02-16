//
//  RMRomotion.m
//  Romo
//

#import "RMRomotion.h"
#import <Romo/RMDispatchTimer.h>
#import <Romo/RMMath.h>

@interface RMRomotion ()

@property (nonatomic, strong) dispatch_queue_t romotionQueue;
@property (nonatomic, strong) RMDispatchTimer *romotionTimer;

@property (nonatomic, strong) NSArray *actions;
@property (nonatomic) double initialHeadAngle;

/** An execution block ran at a high frequency for emotion Romotions */
@property (nonatomic, copy) void (^emotionHandler)(double time);

@property (nonatomic) float leftMotorGain;
@property (nonatomic) float rightMotorGain;
@property (nonatomic) float tiltMotorGain;
@property (nonatomic) float leftMotorMultiplier;
@property (nonatomic) float rightMotorMultiplier;
@property (nonatomic) float tiltMotorMultiplier;

/** Readwrite */
@property (nonatomic, readwrite, getter=isRomoting) BOOL romoting;

@end

@implementation RMRomotion

- (void)dealloc
{
    [self stopRomoting];
    [self.romotionTimer stopRunning];
}

#pragma mark - Public Properties

- (void)setExpression:(RMCharacterExpression)expression
{
    if (expression != RMCharacterExpressionNone) {
        _expression = expression;
        
        NSArray *actions = [self actionsForExpression:expression];
        if (actions.count) {
            [self executeActions:actions];
        }
    }
}

- (void)setEmotion:(RMCharacterEmotion)emotion
{
    _emotion = emotion;
    
    if (self.isRomoting) {
        return;
    }
    
    // Reset all emotion Romotion parameters
    self.leftMotorGain = 0.0;
    self.rightMotorGain = 0.0;
    self.tiltMotorGain = 0.0;
    self.leftMotorMultiplier = 0.0;
    self.rightMotorMultiplier = 0.0;
    self.tiltMotorMultiplier = 0.0;
    self.emotionHandler = [self emotionHandlerForEmotion:emotion];
    
    if (self.intensity > 0.0 && self.emotionHandler) {
        // Start emotion Romotion if we have an intensity & a good emotion
        __weak RMRomotion *weakSelf = self;
        double startTime = currentTime();
        
        self.romotionTimer.eventHandler = ^{
            double runningTime = currentTime() - startTime;
            weakSelf.emotionHandler(runningTime);
            
            float leftMotorPower = (weakSelf.leftMotorMultiplier * weakSelf.robot.leftDriveMotor.powerLevel) + weakSelf.leftMotorGain;
            float rightMotorPower = (weakSelf.rightMotorMultiplier * weakSelf.robot.rightDriveMotor.powerLevel) + weakSelf.rightMotorGain;
            float tiltMotorPower = (weakSelf.tiltMotorMultiplier * weakSelf.robot.tiltMotor.powerLevel) + weakSelf.tiltMotorGain;
            
            [weakSelf.robot driveWithLeftMotorPower:leftMotorPower rightMotorPower:rightMotorPower];
            [weakSelf.robot tiltWithMotorPower:tiltMotorPower];
        };
        
        [self.romotionTimer startRunning];
    } else {
        [self.romotionTimer stopRunning];
        [self.robot stopAllMotion];
    }
}

- (void)setIntensity:(float)intensity
{
    intensity = CLAMP(0.0, intensity, 1.0);
    
    // turning off or turning on
    BOOL isChangingState = (intensity == 0 && _intensity != 0) || (intensity != 0 && _intensity == 0);
    _intensity = intensity;
    
    if (isChangingState) {
        // If we just switched on or off, the emotion handler needs to be flipped
        self.emotion = _emotion;
    }
}

#pragma mark - Public Methods

- (void)stopRomoting
{
    if (self.isRomoting) {
        self.actions = nil;
        _expression = 0;
        
        self.romoting = NO;
        [self.robot stopAllMotion];
    }
}

#pragma mark - Private Methods

- (void)executeActions:(NSArray *)actions
{
    [self stopRomoting];
    [self.romotionTimer stopRunning];

    // if the IMU hasn't started up, flag the initialHeadAngle as invalid
    if (self.robot.robotMotionReady && self.robot.headAngle > 15.0) {
        self.initialHeadAngle = self.robot.headAngle;
    } else {
        self.initialHeadAngle = NAN;
    }
    
    self.romoting = YES;
    self.actions = actions;
    
    __weak RMRomotion *weakSelf = self;
    dispatch_async(self.romotionQueue, ^{
        [weakSelf executeStep:0 forActions:actions];
    });
}

- (void)executeStep:(int)step forActions:(NSArray *)actions
{
    if (step < actions.count && actions == self.actions) {
        RMRomotionAction* action = (RMRomotionAction *)actions[step];
        [action execute];
        
        __weak RMRomotion *weakSelf = self;
        dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(action.duration * NSEC_PER_SEC));
        dispatch_after(popTime, self.romotionQueue, ^(void){
            [weakSelf executeStep:step+1 forActions:actions];
        });
    } else if (step >= actions.count) {
        [self stopRomoting];
        // if the initialHeadAngle is valid (not NAN), return to it
        if (self.initialHeadAngle == self.initialHeadAngle && self.initialHeadAngle >= self.robot.minimumHeadTiltAngle) {
            [self.robot tiltToAngle:self.initialHeadAngle completion:nil];
        }
        
        // Turn on emotion Romotions if necessary
        self.emotion = _emotion;
    }
}

#pragma mark - Private Properties

- (RMDispatchTimer *)romotionTimer
{
    if (!_romotionTimer) {
        _romotionTimer = [[RMDispatchTimer alloc] initWithQueue:self.romotionQueue frequency:20.0];
    }
    return _romotionTimer;
}

- (dispatch_queue_t)romotionQueue
{
    if (!_romotionQueue) {
        _romotionQueue = dispatch_queue_create("com.romotive.Romotions", 0);
    }
    return _romotionQueue;
}

#pragma mark - Actions

- (NSArray *)actionsForExpression:(RMCharacterExpression)expression
{
    NSArray* actions;
    switch (expression) {
        case RMCharacterExpressionAngry: {
            actions = @[
                        [RMRomotionAction actionWithLeftMotorPower:0.0 rightMotorPower:0.0 tiltMotorPower:0.0 forDuration:.1 robot:self.robot],
                        // Jump back
                        [RMRomotionAction actionWithLeftMotorPower:-0.6 rightMotorPower:-0.6 tiltMotorPower:0.0 forDuration:.3 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:0.0 rightMotorPower:0.0 tiltMotorPower:0.0 forDuration:.25 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:0.75 rightMotorPower:0.75 tiltMotorPower:0.0 forDuration:.2 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:0.0 rightMotorPower:0.0 tiltMotorPower:0.0 forDuration:.4 robot:self.robot],
                        // Rock back and forth
                        [RMRomotionAction actionWithLeftMotorPower:0.824 rightMotorPower:0.824 tiltMotorPower:0.0 forDuration:0.1 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:-0.784 rightMotorPower:-0.784 tiltMotorPower:0.0 forDuration:0.1 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:0.745 rightMotorPower:0.745 tiltMotorPower:0.0 forDuration:0.1 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:-0.706 rightMotorPower:-0.706 tiltMotorPower:0.0 forDuration:0.1 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:0.667 rightMotorPower:0.667 tiltMotorPower:0.0 forDuration:0.1 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:-0.627 rightMotorPower:-0.627 tiltMotorPower:0.0 forDuration:0.1 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:0.588 rightMotorPower:0.588 tiltMotorPower:0.0 forDuration:0.1 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:-0.55 rightMotorPower:-0.55 tiltMotorPower:0.0 forDuration:0.1 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:0.55 rightMotorPower:0.55 tiltMotorPower:0.0 forDuration:0.1 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:-0.55 rightMotorPower:-0.55 tiltMotorPower:0.0 forDuration:0.1 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:0.55 rightMotorPower:0.55 tiltMotorPower:0.0 forDuration:0.1 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:-0.55 rightMotorPower:-0.55 tiltMotorPower:0.0 forDuration:0.1 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:0.55 rightMotorPower:0.55 tiltMotorPower:0.0 forDuration:0.1 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:-0.55 rightMotorPower:-0.55 tiltMotorPower:0.0 forDuration:0.1 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:0.55 rightMotorPower:0.55 tiltMotorPower:0.0 forDuration:0.1 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:-0.55 rightMotorPower:-0.55 tiltMotorPower:0.0 forDuration:0.1 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:0.55 rightMotorPower:0.55 tiltMotorPower:0.0 forDuration:0.1 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:-0.55 rightMotorPower:-0.55 tiltMotorPower:0.0 forDuration:0.1 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:0.55 rightMotorPower:0.55 tiltMotorPower:0.0 forDuration:0.1 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:-0.55 rightMotorPower:-0.55 tiltMotorPower:0.0 forDuration:0.1 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:0.55 rightMotorPower:0.55 tiltMotorPower:0.0 forDuration:0.1 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:-0.55 rightMotorPower:-0.55 tiltMotorPower:0.0 forDuration:0.1 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:0.55 rightMotorPower:0.55 tiltMotorPower:0.0 forDuration:0.1 robot:self.robot]
                        ];
        }
            break;
            
        case RMCharacterExpressionBewildered: {
            actions = @[
                        [RMRomotionAction actionWithLeftMotorPower:-0.35 rightMotorPower:-0.35 tiltMotorPower:0.5 forDuration:0.2 robot:self.robot],
                        
                        [RMRomotionAction actionWithLeftMotorPower:0.45 rightMotorPower:0.45 tiltMotorPower:-0.6 forDuration:0.15 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:0.0 rightMotorPower:0.0 tiltMotorPower:-0.2 forDuration:0.25 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:0.0 rightMotorPower:0.0 tiltMotorPower:0.0 forDuration:0.25 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:0.3 rightMotorPower:-0.3 tiltMotorPower:0.7 forDuration:0.25 robot:self.robot],
                        
                        [RMRomotionAction actionWithLeftMotorPower:0.7 rightMotorPower:-0.7 tiltMotorPower:0.0 forDuration:0.15 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:0.0 rightMotorPower:0.0 tiltMotorPower:-0.5 forDuration:0.9 robot:self.robot],
                        
                        [RMRomotionAction actionWithLeftMotorPower:-0.7 rightMotorPower:0.7 tiltMotorPower:0.0 forDuration:0.25 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:0.0 rightMotorPower:0.0 tiltMotorPower:0.5 forDuration:0.75 robot:self.robot],
                        
                        [RMRomotionAction actionWithLeftMotorPower:-0.5 rightMotorPower:-0.5 tiltMotorPower:0.0 forDuration:0.15 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:0.0 rightMotorPower:0.0 tiltMotorPower:0.0 forDuration:0.2 robot:self.robot]
                        ];
            
        }
            break;
            
        case RMCharacterExpressionBored: {
            actions = @[
                        [RMRomotionAction actionWithLeftMotorPower:0.0 rightMotorPower:0.0 tiltMotorPower:0.0 forDuration:0.15 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:-0.6 rightMotorPower:0.6 tiltMotorPower:0.8 forDuration:0.25 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:0.0 rightMotorPower:0.0 tiltMotorPower:0.0 forDuration:0.25 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:0.7 rightMotorPower:-0.7 tiltMotorPower:-0.9 forDuration:0.2 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:0.0 rightMotorPower:0.0 tiltMotorPower:0.0 forDuration:0.3 robot:self.robot],
                        
                        [RMRomotionAction actionWithLeftMotorPower:0.6 rightMotorPower:-0.6 tiltMotorPower:0.8 forDuration:0.25 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:0.0 rightMotorPower:0.0 tiltMotorPower:0.0 forDuration:0.25 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:-0.7 rightMotorPower:0.7 tiltMotorPower:-0.9 forDuration:0.2 robot:self.robot],
                        
                        [RMRomotionAction actionWithLeftMotorPower:0.0 rightMotorPower:0.0 tiltMotorPower:0.0 forDuration:0.75 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:0.0 rightMotorPower:0.0 tiltMotorPower:0.7 forDuration:0.35 robot:self.robot],
                        
                        [RMRomotionAction actionWithLeftMotorPower:0.65 rightMotorPower:-0.65 tiltMotorPower:-0.9 forDuration:0.35 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:0.0 rightMotorPower:0.0 tiltMotorPower:-0.5 forDuration:0.3 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:0.0 rightMotorPower:0.0 tiltMotorPower:0.0 forDuration:0.1 robot:self.robot],
                        
                        [RMRomotionAction actionWithLeftMotorPower:0.0 rightMotorPower:0.0 tiltMotorPower:0.7 forDuration:0.2 robot:self.robot],
                        
                        [RMRomotionAction actionWithLeftMotorPower:-0.65 rightMotorPower:0.65 tiltMotorPower:-0.9 forDuration:0.35 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:0.0 rightMotorPower:0.0 tiltMotorPower:-0.5 forDuration:0.25 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:0.0 rightMotorPower:0.0 tiltMotorPower:0.0 forDuration:0.75 robot:self.robot],
                        
                        [RMRomotionAction actionWithLeftMotorPower:0.0 rightMotorPower:0.0 tiltMotorPower:0.8 forDuration:0.6 robot:self.robot]
                        ];
        }
            break;
            
        case RMCharacterExpressionChuckle: {
            actions = @[
                        [RMRomotionAction actionWithLeftMotorPower:0.3 rightMotorPower:0.3 tiltMotorPower:0.9 forDuration:0.1 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:-0.55 rightMotorPower:-0.55 tiltMotorPower:-0.9 forDuration:0.15 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:-0.5 rightMotorPower:0.0 tiltMotorPower:0.9 forDuration:0.15 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:0.0 rightMotorPower:-0.5 tiltMotorPower:-0.9 forDuration:0.15 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:-0.5 rightMotorPower:0.0 tiltMotorPower:0.9 forDuration:0.15 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:0.45 rightMotorPower:0.3 tiltMotorPower:-0.7 forDuration:0.4 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:0.0 rightMotorPower:0.0 tiltMotorPower:0.0 forDuration:0.5 robot:self.robot]
                        ];
        }
            break;
            
        case RMCharacterExpressionCurious: {
            int firstTilt = arc4random() % 2 ? 1 : -1;
            int firstTurn = arc4random() % 2 ? 1 : -1;
            
            actions = @[
                        [RMRomotionAction actionWithLeftMotorPower:(0.7 * firstTurn) rightMotorPower:(-0.7 * firstTurn) tiltMotorPower:(1.0 * firstTilt) forDuration:0.5 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:0.0 rightMotorPower:0.0 tiltMotorPower:0.0 forDuration:0.75 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:0.0 rightMotorPower:0.0 tiltMotorPower:(1.0 * -firstTilt) forDuration:0.4 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:0.0 rightMotorPower:0.0 tiltMotorPower:0.0 forDuration:0.75 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:(-0.7 * firstTurn) rightMotorPower:(0.7 * firstTurn) tiltMotorPower:(1.0 * firstTilt) forDuration:0.5 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:0.0 rightMotorPower:0.0 tiltMotorPower:0.0 forDuration:2.0 robot:self.robot],
                        ];
        }
            break;
            
        case RMCharacterExpressionDizzy: {
            actions = @[
                        [RMRomotionAction actionWithLeftMotorPower:0.0 rightMotorPower:0.0 tiltMotorPower:0.0 forDuration:.4 robot:self.robot],
                        // Look up & left
                        [RMRomotionAction actionWithLeftMotorPower:-0.6 rightMotorPower:0.6 tiltMotorPower:-0.4 forDuration:.4 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:0.0 rightMotorPower:0.0 tiltMotorPower:0.0 forDuration:.4 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:0.6 rightMotorPower:-0.6 tiltMotorPower:0.4 forDuration:.4 robot:self.robot],
                        // Look up & right
                        [RMRomotionAction actionWithLeftMotorPower:0.4 rightMotorPower:-0.4 tiltMotorPower:-0.3 forDuration:.5 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:-0.3 rightMotorPower:0.3 tiltMotorPower:0.3 forDuration:.4 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:0.0 rightMotorPower:0.0 tiltMotorPower:0.0 forDuration:.25 robot:self.robot],
                        // Shake left and right
                        [RMRomotionAction actionWithLeftMotorPower:0.667 rightMotorPower:-0.667 tiltMotorPower:0.0 forDuration:0.1 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:-0.627 rightMotorPower:0.627 tiltMotorPower:0.0 forDuration:0.1 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:0.667 rightMotorPower:-0.667 tiltMotorPower:0.0 forDuration:0.1 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:-0.627 rightMotorPower:0.627 tiltMotorPower:0.0 forDuration:0.1 robot:self.robot]
                        ];
        }
            break;
            
        case RMCharacterExpressionEmbarrassed: {
            actions = @[
                        [RMRomotionAction actionWithLeftMotorPower:0.0 rightMotorPower:0.0 tiltMotorPower:0.0 forDuration:.2 robot:self.robot],
                        // Look down & right
                        [RMRomotionAction actionWithLeftMotorPower:0.6 rightMotorPower:-0.6 tiltMotorPower:0.9 forDuration:.4 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:0.0 rightMotorPower:0.0 tiltMotorPower:0.4 forDuration:0.5 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:0.0 rightMotorPower:0.0 tiltMotorPower:0.0 forDuration:0.7 robot:self.robot],
                        // Look back
                        [RMRomotionAction actionWithLeftMotorPower:-0.6 rightMotorPower:0.6 tiltMotorPower:-0.9 forDuration:.4 robot:self.robot]
                        ];
        }
            break;
            
        case RMCharacterExpressionExcited: {
            actions = @[
                        [RMRomotionAction actionWithLeftMotorPower:0.0 rightMotorPower:0.0 tiltMotorPower:0.0 forDuration:0.2 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:-0.843 rightMotorPower:0.843 tiltMotorPower:0.0 forDuration:0.1 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:0.843 rightMotorPower:-0.843 tiltMotorPower:0.0 forDuration:0.1 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:-0.843 rightMotorPower:0.784 tiltMotorPower:0.0 forDuration:0.1 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:0.843 rightMotorPower:-0.784 tiltMotorPower:0.0 forDuration:0.1 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:-0.843 rightMotorPower:0.706 tiltMotorPower:0.0 forDuration:0.1 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:0.843 rightMotorPower:-0.706 tiltMotorPower:0.0 forDuration:0.1 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:-0.843 rightMotorPower:0.588 tiltMotorPower:0.0 forDuration:0.1 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:0.843 rightMotorPower:-0.588 tiltMotorPower:0.0 forDuration:0.1 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:0.0 rightMotorPower:0.0 tiltMotorPower:0.0 forDuration:0.5 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:0.5 rightMotorPower:-0.5 tiltMotorPower:-0.5 forDuration:0.5 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:0.0 rightMotorPower:0.0 tiltMotorPower:0.4 forDuration:0.5 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:-0.5 rightMotorPower:0.5 tiltMotorPower:-0.5 forDuration:0.5 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:0.0 rightMotorPower:0.0 tiltMotorPower:0.4 forDuration:0.3 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:0.0 rightMotorPower:0.0 tiltMotorPower:0.0 forDuration:1.0 robot:self.robot]
                        ];
        }
            break;
            
        case RMCharacterExpressionExhausted: {
            actions = @[
                        [RMRomotionAction actionWithLeftMotorPower:0.0 rightMotorPower:0.0 tiltMotorPower:0.0 forDuration:0.2 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:-0.5 rightMotorPower:-0.5 tiltMotorPower:-0.7 forDuration:0.3 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:0.5 rightMotorPower:0.5 tiltMotorPower:0.6 forDuration:0.2 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:0.0 rightMotorPower:0.0 tiltMotorPower:0.6 forDuration:0.4 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:0.0 rightMotorPower:0.0 tiltMotorPower:0.0 forDuration:0.2 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:0.0 rightMotorPower:0.0 tiltMotorPower:-0.6 forDuration:0.4 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:0.0 rightMotorPower:0.0 tiltMotorPower:0.7 forDuration:0.4 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:0.0 rightMotorPower:0.0 tiltMotorPower:-0.5 forDuration:0.4 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:0.4 rightMotorPower:0.4 tiltMotorPower:0.8 forDuration:0.45 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:0.0 rightMotorPower:0.0 tiltMotorPower:0.0 forDuration:0.3 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:-0.6 rightMotorPower:0.6 tiltMotorPower:-0.6 forDuration:0.1 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:0.6 rightMotorPower:-0.6 tiltMotorPower:-0.5 forDuration:0.1 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:-0.6 rightMotorPower:0.6 tiltMotorPower:-0.4 forDuration:0.1 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:0.6 rightMotorPower:-0.6 tiltMotorPower:-0.5 forDuration:0.1 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:0.0 rightMotorPower:0.0 tiltMotorPower:0.0 forDuration:0.4 robot:self.robot]
                        ];
        }
            break;
            
        case RMCharacterExpressionFart: {
            int numFartRoutines = 3;
            int randomSeed = arc4random_uniform(numFartRoutines);
            if (randomSeed == 0) {
                actions = @[
                            [RMRomotionAction actionWithLeftMotorPower:0.0 rightMotorPower:0.0 tiltMotorPower:0.65 forDuration:0.25 robot:self.robot],
                            [RMRomotionAction actionWithLeftMotorPower:0.8 rightMotorPower:0.8 tiltMotorPower:-0.9 forDuration:0.1 robot:self.robot],
                            [RMRomotionAction actionWithLeftMotorPower:0.0 rightMotorPower:0.0 tiltMotorPower:0.0 forDuration:0.15 robot:self.robot],
                            [RMRomotionAction actionWithLeftMotorPower:0.0 rightMotorPower:0.0 tiltMotorPower:0.6 forDuration:0.1 robot:self.robot],
                            [RMRomotionAction actionWithLeftMotorPower:0.0 rightMotorPower:0.0 tiltMotorPower:0.0 forDuration:0.15 robot:self.robot]
                            ];
            } else if (randomSeed == 1) {
                int turnDirection = arc4random() % 2 ? 1 : -1;
                actions = @[
                            [RMRomotionAction actionWithLeftMotorPower:0.0 rightMotorPower:0.0 tiltMotorPower:0.65 forDuration:0.25 robot:self.robot],
                            [RMRomotionAction actionWithLeftMotorPower:-0.75*turnDirection rightMotorPower:0.75*turnDirection tiltMotorPower:-0.9 forDuration:0.1 robot:self.robot],
                            [RMRomotionAction actionWithLeftMotorPower:-0.55*turnDirection rightMotorPower:0.55*turnDirection tiltMotorPower:0.0 forDuration:0.15 robot:self.robot],
                            [RMRomotionAction actionWithLeftMotorPower:0.0 rightMotorPower:0.0 tiltMotorPower:0.6 forDuration:0.1 robot:self.robot],
                            [RMRomotionAction actionWithLeftMotorPower:0.0 rightMotorPower:0.0 tiltMotorPower:0.0 forDuration:0.15 robot:self.robot]
                            ];
            } else if (randomSeed == 2) {
                actions = @[
                            [RMRomotionAction actionWithLeftMotorPower:-0.5 rightMotorPower:-0.5 tiltMotorPower:0.0 forDuration:0.15 robot:self.robot],
                            [RMRomotionAction actionWithLeftMotorPower:0.0 rightMotorPower:0.0 tiltMotorPower:0.65 forDuration:0.25 robot:self.robot],
                            
                            [RMRomotionAction actionWithLeftMotorPower:0.0 rightMotorPower:0.0 tiltMotorPower:0.8 forDuration:0.15 robot:self.robot],
                            [RMRomotionAction actionWithLeftMotorPower:0.0 rightMotorPower:0.0 tiltMotorPower:0.0 forDuration:0.25 robot:self.robot],
                            [RMRomotionAction actionWithLeftMotorPower:0.0 rightMotorPower:0.0 tiltMotorPower:-0.6 forDuration:0.45 robot:self.robot]
                            ];
            }
        }
            break;
            
        case RMCharacterExpressionHappy: {
            actions = @[
                        [RMRomotionAction actionWithLeftMotorPower:0.0 rightMotorPower:0.0 tiltMotorPower:0.0 forDuration:0.1 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:0.4 rightMotorPower:0.4 tiltMotorPower:-0.65 forDuration:0.2 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:0.0 rightMotorPower:0.0 tiltMotorPower:0.0 forDuration:0.6 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:0.588 rightMotorPower:-0.588 tiltMotorPower:-0.8 forDuration:0.4 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:0.0 rightMotorPower:0.0 tiltMotorPower:0.45 forDuration:0.45 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:-0.588 rightMotorPower:0.588 tiltMotorPower:-0.8 forDuration:0.35 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:0.0 rightMotorPower:0.0 tiltMotorPower:0.3 forDuration:0.4 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:0.0 rightMotorPower:0.0 tiltMotorPower:0.0 forDuration:0.5 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:0.0 rightMotorPower:0.0 tiltMotorPower:0.5 forDuration:0.7 robot:self.robot]
                        ];
        }
            break;
            
        case RMCharacterExpressionHiccup: {
            actions = @[
                        [RMRomotionAction actionWithLeftMotorPower:0.0 rightMotorPower:0.0 tiltMotorPower:0.65 forDuration:0.15 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:-0.8 rightMotorPower:-0.8 tiltMotorPower:-0.9 forDuration:0.1 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:0.0 rightMotorPower:0.0 tiltMotorPower:0.0 forDuration:0.15 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:0.0 rightMotorPower:0.0 tiltMotorPower:0.6 forDuration:0.1 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:0.0 rightMotorPower:0.0 tiltMotorPower:0.0 forDuration:0.15 robot:self.robot]
                        ];
        }
            break;
            
        case RMCharacterExpressionHoldingBreath: {
            actions = @[
                        [RMRomotionAction actionWithLeftMotorPower:0.4 rightMotorPower:0.4 tiltMotorPower:0.75 forDuration:0.2 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:0.0 rightMotorPower:0.0 tiltMotorPower:0.0 forDuration:0.05 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:-0.4 rightMotorPower:-0.4 tiltMotorPower:-0.85 forDuration:0.4 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:0.0 rightMotorPower:0.0 tiltMotorPower:-0.6 forDuration:0.2 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:0.0 rightMotorPower:0.0 tiltMotorPower:0.0 forDuration:0.25 robot:self.robot],
                        
                        [RMRomotionAction actionWithLeftMotorPower:-0.6 rightMotorPower:0.6 tiltMotorPower:0.0 forDuration:0.05 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:0.6 rightMotorPower:-0.6 tiltMotorPower:0.0 forDuration:0.05 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:-0.6 rightMotorPower:0.6 tiltMotorPower:0.0 forDuration:0.05 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:0.6 rightMotorPower:-0.6 tiltMotorPower:0.0 forDuration:0.05 robot:self.robot],
                        
                        [RMRomotionAction actionWithLeftMotorPower:0.0 rightMotorPower:0.0 tiltMotorPower:0.0 forDuration:0.5 robot:self.robot],
                        
                        [RMRomotionAction actionWithLeftMotorPower:0.5 rightMotorPower:0.5 tiltMotorPower:0.7 forDuration:0.2 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:0.0 rightMotorPower:0.0 tiltMotorPower:0.4 forDuration:0.35 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:0.0 rightMotorPower:0.0 tiltMotorPower:0.25 forDuration:0.5 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:0.0 rightMotorPower:0.0 tiltMotorPower:0.0 forDuration:0.6 robot:self.robot]
                        ];
        }
            break;
            
        case RMCharacterExpressionLaugh: {
            actions = @[
                        [RMRomotionAction actionWithLeftMotorPower:-0.4 rightMotorPower:-0.4 tiltMotorPower:-0.784 forDuration:0.3 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:0.45 rightMotorPower:0.45 tiltMotorPower:1.0 forDuration:0.37 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:-0.4 rightMotorPower:-0.4 tiltMotorPower:-0.784 forDuration:0.3 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:0.0 rightMotorPower:0.0 tiltMotorPower:0.0 forDuration:1.0 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:0.0 rightMotorPower:0.0 tiltMotorPower:0.5 forDuration:0.45 robot:self.robot]
                        ];
        }
            break;
            
        case RMCharacterExpressionLetDown: {
            actions = @[
                        [RMRomotionAction actionWithLeftMotorPower:0.0 rightMotorPower:0.0 tiltMotorPower:0.0 forDuration:0.45 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:-0.5 rightMotorPower:-0.5 tiltMotorPower:-0.9 forDuration:0.3 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:0.0 rightMotorPower:0.0 tiltMotorPower:0.0 forDuration:0.2 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:0.5 rightMotorPower:0.5 tiltMotorPower:0.5 forDuration:0.6 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:0.2 rightMotorPower:0.2 tiltMotorPower:0.35 forDuration:0.9 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:0.0 rightMotorPower:0.0 tiltMotorPower:0.0 forDuration:0.5 robot:self.robot]
                        ];
        }
            break;
            
        case RMCharacterExpressionLookingAround: {
            actions = @[
                        [RMRomotionAction actionWithLeftMotorPower:0.4 rightMotorPower:0.4 tiltMotorPower:0.6 forDuration:0.15 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:-0.725 rightMotorPower:0.725 tiltMotorPower:-0.8 forDuration:0.4 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:0.0 rightMotorPower:0.0 tiltMotorPower:0.0 forDuration:0.45 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:0.7 rightMotorPower:-0.7 tiltMotorPower:-0.9 forDuration:0.5 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:0.0 rightMotorPower:0.0 tiltMotorPower:0.0 forDuration:0.7 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:-0.3 rightMotorPower:0.3 tiltMotorPower:0.8 forDuration:0.4 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:0.0 rightMotorPower:0.0 tiltMotorPower:0.6 forDuration:0.6 robot:self.robot]
                        ];
        }
            break;
            
        case RMCharacterExpressionLove: {
            actions = @[
                        [RMRomotionAction actionWithLeftMotorPower:-0.4 rightMotorPower:-0.4 tiltMotorPower:0.7 forDuration:0.2 robot:self.robot],
                        
                        [RMRomotionAction actionWithLeftMotorPower:0.0 rightMotorPower:0.0 tiltMotorPower:0.0 forDuration:0.2 robot:self.robot],
                        
                        [RMRomotionAction actionWithLeftMotorPower:0.6 rightMotorPower:0.0 tiltMotorPower:-0.6 forDuration:0.2 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:0.0 rightMotorPower:0.0 tiltMotorPower:0.0 forDuration:0.1 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:0.0 rightMotorPower:0.6 tiltMotorPower:-0.6 forDuration:0.2 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:0.0 rightMotorPower:0.0 tiltMotorPower:0.0 forDuration:0.1 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:0.6 rightMotorPower:0.0 tiltMotorPower:-0.6 forDuration:0.2 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:0.0 rightMotorPower:0.0 tiltMotorPower:0.0 forDuration:1.25 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:0.0 rightMotorPower:0.3 tiltMotorPower:0.4 forDuration:0.6 robot:self.robot]
                        ];
        }
            break;
            
        case RMCharacterExpressionPonder: {
            actions = @[
                        [RMRomotionAction actionWithLeftMotorPower:0.0 rightMotorPower:0.0 tiltMotorPower:0.85 forDuration:0.1 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:0.0 rightMotorPower:0.0 tiltMotorPower:0.0 forDuration:0.15 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:0.65 rightMotorPower:-0.65 tiltMotorPower:-0.8 forDuration:0.2 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:0.0 rightMotorPower:0.0 tiltMotorPower:-0.7 forDuration:0.3 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:0.0 rightMotorPower:0.0 tiltMotorPower:0.0 forDuration:0.7 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:-0.65 rightMotorPower:0.65 tiltMotorPower:-0.8 forDuration:0.3 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:0.0 rightMotorPower:0.0 tiltMotorPower:0.0 forDuration:0.7 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:0.0 rightMotorPower:0.0 tiltMotorPower:0.825 forDuration:0.7 robot:self.robot]
                        ];
        }
            break;
            
        case RMCharacterExpressionProud: {
            actions = @[
                        [RMRomotionAction actionWithLeftMotorPower:0.0 rightMotorPower:0.0 tiltMotorPower:0.0 forDuration:0.15 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:-0.6 rightMotorPower:0.5 tiltMotorPower:0.6 forDuration:0.2 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:0.5 rightMotorPower:-0.6 tiltMotorPower:0.7 forDuration:0.2 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:-0.6 rightMotorPower:0.5 tiltMotorPower:0.8 forDuration:0.2 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:0.5 rightMotorPower:-0.6 tiltMotorPower:-0.6 forDuration:0.2 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:0.0 rightMotorPower:0.0 tiltMotorPower:-0.45 forDuration:0.5 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:0.0 rightMotorPower:0.0 tiltMotorPower:0.0 forDuration:0.2 robot:self.robot]
                        ];
        }
            break;
            
        case RMCharacterExpressionSad: {
            actions = @[
                        [RMRomotionAction actionWithLeftMotorPower:0.0 rightMotorPower:0.0 tiltMotorPower:0.0 forDuration:0.45 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:-0.5 rightMotorPower:-0.5 tiltMotorPower:-0.5 forDuration:0.2 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:0.0 rightMotorPower:0.0 tiltMotorPower:0.0 forDuration:0.2 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:0.4 rightMotorPower:0.4 tiltMotorPower:0.7 forDuration:0.5 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:0.0 rightMotorPower:0.0 tiltMotorPower:0.4 forDuration:0.5 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:0.0 rightMotorPower:0.0 tiltMotorPower:0.0 forDuration:1.25 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:0.0 rightMotorPower:0.0 tiltMotorPower:-0.5 forDuration:0.5 robot:self.robot]
                        ];
        }
            break;
            
        case RMCharacterExpressionScared: {
            actions = @[
                        [RMRomotionAction actionWithLeftMotorPower:0.0 rightMotorPower:0.0 tiltMotorPower:0.0 forDuration:0.3 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:-0.5 rightMotorPower:-0.5 tiltMotorPower:-0.7 forDuration:0.1 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:-0.8 rightMotorPower:-0.8 tiltMotorPower:-0.0 forDuration:0.1 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:0.0 rightMotorPower:0.0 tiltMotorPower:0.8 forDuration:0.15 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:0.0 rightMotorPower:0.0 tiltMotorPower:0.0 forDuration:0.5 robot:self.robot],
                        
                        [RMRomotionAction actionWithLeftMotorPower:0.8 rightMotorPower:-0.8 tiltMotorPower:0.0 forDuration:0.2 robot:self.robot],
                        
                        [RMRomotionAction actionWithLeftMotorPower:-0.6 rightMotorPower:0.6 tiltMotorPower:0.0 forDuration:0.05 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:0.6 rightMotorPower:-0.6 tiltMotorPower:0.0 forDuration:0.05 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:-0.6 rightMotorPower:0.6 tiltMotorPower:0.0 forDuration:0.05 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:0.6 rightMotorPower:-0.6 tiltMotorPower:0.0 forDuration:0.05 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:-0.6 rightMotorPower:0.6 tiltMotorPower:0.0 forDuration:0.05 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:0.6 rightMotorPower:-0.6 tiltMotorPower:0.0 forDuration:0.05 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:-0.6 rightMotorPower:0.6 tiltMotorPower:0.0 forDuration:0.05 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:0.6 rightMotorPower:-0.6 tiltMotorPower:0.0 forDuration:0.05 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:-0.6 rightMotorPower:0.6 tiltMotorPower:0.0 forDuration:0.05 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:0.6 rightMotorPower:-0.6 tiltMotorPower:0.0 forDuration:0.05 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:-0.6 rightMotorPower:0.6 tiltMotorPower:0.0 forDuration:0.05 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:0.6 rightMotorPower:-0.6 tiltMotorPower:0.0 forDuration:0.05 robot:self.robot],
                        
                        [RMRomotionAction actionWithLeftMotorPower:-0.75 rightMotorPower:0.75 tiltMotorPower:0.0 forDuration:0.4 robot:self.robot],
                        
                        [RMRomotionAction actionWithLeftMotorPower:-0.6 rightMotorPower:0.6 tiltMotorPower:0.0 forDuration:0.05 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:0.6 rightMotorPower:-0.6 tiltMotorPower:0.0 forDuration:0.05 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:-0.6 rightMotorPower:0.6 tiltMotorPower:0.0 forDuration:0.05 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:0.6 rightMotorPower:-0.6 tiltMotorPower:0.0 forDuration:0.05 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:-0.6 rightMotorPower:0.6 tiltMotorPower:0.0 forDuration:0.05 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:0.6 rightMotorPower:-0.6 tiltMotorPower:0.0 forDuration:0.05 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:-0.6 rightMotorPower:0.6 tiltMotorPower:0.0 forDuration:0.05 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:0.6 rightMotorPower:-0.6 tiltMotorPower:0.0 forDuration:0.05 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:-0.6 rightMotorPower:0.6 tiltMotorPower:0.0 forDuration:0.05 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:0.6 rightMotorPower:-0.6 tiltMotorPower:0.0 forDuration:0.05 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:-0.6 rightMotorPower:0.6 tiltMotorPower:0.0 forDuration:0.05 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:0.6 rightMotorPower:-0.6 tiltMotorPower:0.0 forDuration:0.05 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:-0.6 rightMotorPower:0.6 tiltMotorPower:0.0 forDuration:0.05 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:0.6 rightMotorPower:-0.6 tiltMotorPower:0.0 forDuration:0.05 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:-0.6 rightMotorPower:0.6 tiltMotorPower:0.0 forDuration:0.05 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:0.6 rightMotorPower:-0.6 tiltMotorPower:0.0 forDuration:0.05 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:-0.6 rightMotorPower:0.6 tiltMotorPower:0.0 forDuration:0.05 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:0.6 rightMotorPower:-0.6 tiltMotorPower:0.0 forDuration:0.05 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:-0.6 rightMotorPower:0.6 tiltMotorPower:0.0 forDuration:0.05 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:0.6 rightMotorPower:-0.6 tiltMotorPower:0.0 forDuration:0.05 robot:self.robot],
                        
                        [RMRomotionAction actionWithLeftMotorPower:0.0 rightMotorPower:0.0 tiltMotorPower:0.0 forDuration:0.2 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:0.6 rightMotorPower:-0.6 tiltMotorPower:0.0 forDuration:0.25 robot:self.robot]
                        ];
        }
            break;
            
        case RMCharacterExpressionSleepy: {
            actions = @[
                        [RMRomotionAction actionWithLeftMotorPower:-0.5 rightMotorPower:-0.5 tiltMotorPower:-0.9 forDuration:0.2 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:0.0 rightMotorPower:0.0 tiltMotorPower:-0.8 forDuration:0.3 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:0.5 rightMotorPower:0.5 tiltMotorPower:0.7 forDuration:0.25 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:0.0 rightMotorPower:0.0 tiltMotorPower:0.6 forDuration:1.25 robot:self.robot],
                        
                        [RMRomotionAction actionWithLeftMotorPower:-0.5 rightMotorPower:-0.5 tiltMotorPower:-0.9 forDuration:0.2 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:0.0 rightMotorPower:0.0 tiltMotorPower:-0.8 forDuration:0.45 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:0.5 rightMotorPower:0.5 tiltMotorPower:0.7 forDuration:0.25 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:0.0 rightMotorPower:0.0 tiltMotorPower:0.6 forDuration:1.5 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:0.0 rightMotorPower:0.0 tiltMotorPower:0.0 forDuration:1.0 robot:self.robot],
                        
                        [RMRomotionAction actionWithLeftMotorPower:0.0 rightMotorPower:0.0 tiltMotorPower:-0.9 forDuration:0.7 robot:self.robot],
                        
                        [RMRomotionAction actionWithLeftMotorPower:-0.6 rightMotorPower:0.6 tiltMotorPower:0.9 forDuration:0.2 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:0.0 rightMotorPower:0.0 tiltMotorPower:0.0 forDuration:0.1 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:0.6 rightMotorPower:-0.6 tiltMotorPower:0.9 forDuration:0.2 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:0.0 rightMotorPower:0.0 tiltMotorPower:0.0 forDuration:0.1 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:-0.6 rightMotorPower:0.6 tiltMotorPower:0.9 forDuration:0.2 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:0.0 rightMotorPower:0.0 tiltMotorPower:0.0 forDuration:0.1 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:0.6 rightMotorPower:-0.6 tiltMotorPower:0.9 forDuration:0.2 robot:self.robot],
                        
                        [RMRomotionAction actionWithLeftMotorPower:0.0 rightMotorPower:0.0 tiltMotorPower:0.0 forDuration:0.5 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:0.0 rightMotorPower:0.0 tiltMotorPower:-0.75 forDuration:0.65 robot:self.robot]
                        ];
        }
            break;
            
        case RMCharacterExpressionSneeze: {
            actions = @[
                        [RMRomotionAction actionWithLeftMotorPower:0.0 rightMotorPower:0.0 tiltMotorPower:0.0 forDuration:0.15 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:-0.588 rightMotorPower:-0.588 tiltMotorPower:-0.588 forDuration:0.2 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:0.0 rightMotorPower:0.0 tiltMotorPower:-0.65 forDuration:0.2 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:0.588 rightMotorPower:0.588 tiltMotorPower:1.0 forDuration:0.15 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:0.0 rightMotorPower:0.0 tiltMotorPower:0.8 forDuration:0.5 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:0.0 rightMotorPower:0.0 tiltMotorPower:0.0 forDuration:1.4 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:-0.4 rightMotorPower:-0.4 tiltMotorPower:-0.6 forDuration:0.2 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:0.0 rightMotorPower:0.0 tiltMotorPower:-0.6 forDuration:0.4 robot:self.robot]
                        ];
        }
            break;
            
        case RMCharacterExpressionSniff: {
            actions = @[
                        [RMRomotionAction actionWithLeftMotorPower:-0.5 rightMotorPower:-0.5 tiltMotorPower:1.0 forDuration:0.2 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:0.0 rightMotorPower:0.0 tiltMotorPower:0.9 forDuration:0.2 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:0.6 rightMotorPower:0.2 tiltMotorPower:0.8 forDuration:0.15 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:0.2 rightMotorPower:0.6 tiltMotorPower:0.7 forDuration:0.15 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:0.6 rightMotorPower:0.2 tiltMotorPower:0.0 forDuration:0.15 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:0.2 rightMotorPower:0.6 tiltMotorPower:0.0 forDuration:0.15 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:0.6 rightMotorPower:0.2 tiltMotorPower:-0.8 forDuration:0.2 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:0.2 rightMotorPower:0.6 tiltMotorPower:0.6 forDuration:0.2 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:0.0 rightMotorPower:0.0 tiltMotorPower:-0.8 forDuration:0.3 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:0.0 rightMotorPower:0.0 tiltMotorPower:-0.5 forDuration:0.2 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:0.0 rightMotorPower:0.0 tiltMotorPower:0.0 forDuration:0.2 robot:self.robot]
                        ];
        }
            break;
            
        case RMCharacterExpressionStartled: {
            actions = @[
                        [RMRomotionAction actionWithLeftMotorPower:-0.8 rightMotorPower:-0.8 tiltMotorPower:-0.8 forDuration:0.15 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:-0.4 rightMotorPower:-0.5 tiltMotorPower:-0.7 forDuration:0.15 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:-0.5 rightMotorPower:-0.4 tiltMotorPower:-0.6 forDuration:0.15 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:0.0 rightMotorPower:0.45 tiltMotorPower:-0.8 forDuration:0.15 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:0.45 rightMotorPower:0.0 tiltMotorPower:-0.8 forDuration:0.15 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:0.0 rightMotorPower:0.45 tiltMotorPower:-0.8 forDuration:0.15 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:0.45 rightMotorPower:0.0 tiltMotorPower:-0.7 forDuration:0.15 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:0.0 rightMotorPower:0.45 tiltMotorPower:0.0 forDuration:0.15 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:0.0 rightMotorPower:0.0 tiltMotorPower:0.0 forDuration:0.4 robot:self.robot]
                        ];
        }
            break;
            
        case RMCharacterExpressionTalking: {
            actions = @[
                        [RMRomotionAction actionWithLeftMotorPower:-0.5 rightMotorPower:-0.5 tiltMotorPower:0.9 forDuration:0.2 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:0.45 rightMotorPower:0.45 tiltMotorPower:-0.8 forDuration:0.45 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:0.0 rightMotorPower:0.0 tiltMotorPower:0.0 forDuration:0.15 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:0.5 rightMotorPower:0.5 tiltMotorPower:0.9 forDuration:0.15 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:0.0 rightMotorPower:0.0 tiltMotorPower:0.0 forDuration:0.15 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:0.5 rightMotorPower:0.5 tiltMotorPower:-0.9 forDuration:0.15 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:0.0 rightMotorPower:0.0 tiltMotorPower:0.0 forDuration:0.5 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:-0.5 rightMotorPower:-0.5 tiltMotorPower:0.65 forDuration:0.45 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:0.0 rightMotorPower:0.0 tiltMotorPower:0.0 forDuration:0.3 robot:self.robot]
                        ];
        }
            break;
            
        case RMCharacterExpressionWant: {
            actions = @[
                        [RMRomotionAction actionWithLeftMotorPower:-0.5 rightMotorPower:-0.5 tiltMotorPower:-0.7 forDuration:0.15 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:0.0 rightMotorPower:0.0 tiltMotorPower:0.7 forDuration:0.1 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:0.45 rightMotorPower:0.45 tiltMotorPower:0.9 forDuration:0.2 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:0.45 rightMotorPower:0.45 tiltMotorPower:-0.6 forDuration:0.2 robot:self.robot],
                        
                        [RMRomotionAction actionWithLeftMotorPower:0.0 rightMotorPower:0.0 tiltMotorPower:-0.7 forDuration:0.15 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:0.0 rightMotorPower:0.0 tiltMotorPower:-0.8 forDuration:0.15 robot:self.robot],
                        
                        [RMRomotionAction actionWithLeftMotorPower:0.0 rightMotorPower:0.0 tiltMotorPower:0.0 forDuration:0.15 robot:self.robot],
                        
                        [RMRomotionAction actionWithLeftMotorPower:-0.7 rightMotorPower:-0.7 tiltMotorPower:0.5 forDuration:0.2 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:0.0 rightMotorPower:0.0 tiltMotorPower:0.7 forDuration:0.15 robot:self.robot],
                        
                        [RMRomotionAction actionWithLeftMotorPower:0.7 rightMotorPower:0.7 tiltMotorPower:0.0 forDuration:0.15 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:-0.7 rightMotorPower:-0.7 tiltMotorPower:0.0 forDuration:0.15 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:0.7 rightMotorPower:0.7 tiltMotorPower:0.0 forDuration:0.15 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:-0.7 rightMotorPower:-0.7 tiltMotorPower:0.0 forDuration:0.15 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:0.7 rightMotorPower:0.7 tiltMotorPower:0.0 forDuration:0.15 robot:self.robot],
                        
                        [RMRomotionAction actionWithLeftMotorPower:0.0 rightMotorPower:0.0 tiltMotorPower:0.0 forDuration:0.5 robot:self.robot]
                        ];
        }
            break;
            
        case RMCharacterExpressionYawn: {
            actions = @[
                        [RMRomotionAction actionWithLeftMotorPower:0.0 rightMotorPower:0.0 tiltMotorPower:0.0 forDuration:0.1 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:-0.3 rightMotorPower:-0.3 tiltMotorPower:0.7 forDuration:0.3 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:0.3 rightMotorPower:0.3 tiltMotorPower:-0.43 forDuration:0.8 robot:self.robot],
                        
                        [RMRomotionAction actionWithLeftMotorPower:0.0 rightMotorPower:0.0 tiltMotorPower:0.0 forDuration:0.2 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:0.0 rightMotorPower:0.0 tiltMotorPower:0.35 forDuration:1.0 robot:self.robot],
                        
                        [RMRomotionAction actionWithLeftMotorPower:0.0 rightMotorPower:0.0 tiltMotorPower:0.0 forDuration:0.7 robot:self.robot],
                        
                        [RMRomotionAction actionWithLeftMotorPower:-0.55 rightMotorPower:0.0 tiltMotorPower:0.0 forDuration:0.2 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:0.0 rightMotorPower:-0.55 tiltMotorPower:0.0 forDuration:0.2 robot:self.robot],
                        
                        [RMRomotionAction actionWithLeftMotorPower:0.0 rightMotorPower:0.0 tiltMotorPower:0.0 forDuration:0.8 robot:self.robot]
                        ];
        }
            break;
            
        case RMCharacterExpressionYippee: {
            actions = @[
                        [RMRomotionAction actionWithLeftMotorPower:0.5 rightMotorPower:0.5 tiltMotorPower:0.4 forDuration:0.15 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:0.0 rightMotorPower:0.0 tiltMotorPower:-0.5 forDuration:0.15 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:-0.8 rightMotorPower:0.5 tiltMotorPower:-0.6 forDuration:0.2 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:0.5 rightMotorPower:-0.8 tiltMotorPower:-0.7 forDuration:0.2 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:-0.45 rightMotorPower:-0.45 tiltMotorPower:-0.4 forDuration:0.3 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:0.0 rightMotorPower:0.0 tiltMotorPower:0.0 forDuration:0.25 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:0.4 rightMotorPower:0.4 tiltMotorPower:0.5 forDuration:0.25 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:0.0 rightMotorPower:0.0 tiltMotorPower:-0.5 forDuration:0.15 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:0.0 rightMotorPower:0.0 tiltMotorPower:0.0 forDuration:0.45 robot:self.robot],
                        [RMRomotionAction actionWithLeftMotorPower:0.0 rightMotorPower:0.0 tiltMotorPower:0.35 forDuration:0.15 robot:self.robot]
                        ];
        }
            break;
            
        default:
            break;
    }
    return actions;
}

- (void (^)(double))emotionHandlerForEmotion:(RMCharacterEmotion)emotion
{
    void (^emotionHandler)(double time) = nil;
    
    __weak RMRomotion *weakSelf = self;
    switch (emotion) {
        case RMCharacterEmotionCurious: {
            break;
        }
            
        case RMCharacterEmotionExcited: {
            // rock back and forth, oscillating head back as we go forward, head down as we go back
            emotionHandler = ^(double time){
                float Hertz = 1.0 * (1.0 + weakSelf.intensity) / 2.0;
                float oscillation = sinf(Hertz * 2 * M_PI * time);
                
                float forwardGain = 0.75 * oscillation * weakSelf.intensity;
                weakSelf.leftMotorGain = forwardGain;
                weakSelf.rightMotorGain = forwardGain;
                
                float tiltGain = -3.0 * oscillation * weakSelf.intensity;
                weakSelf.tiltMotorGain = tiltGain;
            };
            break;
        }
            
        case RMCharacterEmotionHappy: {
            break;
        }
            
        case RMCharacterEmotionSad: {
            emotionHandler = ^(double time){
                weakSelf.leftMotorMultiplier = 1.0 - weakSelf.intensity;
                weakSelf.rightMotorMultiplier = 1.0 - weakSelf.intensity;
                weakSelf.tiltMotorMultiplier = 0.0;
            };
            break;
        }
            
        case RMCharacterEmotionScared: {
            // shake back and forth with oscillating amplitude
            emotionHandler = ^(double time){
                static BOOL left = YES;
                float shakeGain = (left ? 1.0 : -1.0) * weakSelf.intensity;
                weakSelf.leftMotorGain = shakeGain;
                weakSelf.rightMotorGain = -shakeGain;
                weakSelf.tiltMotorGain = 0.0;
                left = !left;
            };
            break;
        }
            
        case RMCharacterEmotionSleeping: {
            emotionHandler = ^(double time){
                int timeInt = (int)time;
                
                float gain = 0.24 * (2.0 + weakSelf.intensity) / 3.0;
                
                if (gain > 0.14 && weakSelf.intensity > 0.0) {
                    if (timeInt % 6 < 3) {
                        weakSelf.tiltMotorGain = -gain;
                    } else {
                        weakSelf.tiltMotorGain = gain;
                    }
                }
                
                weakSelf.leftMotorGain = 0.0;
                weakSelf.rightMotorGain = 0.0;
            };
            break;
        }
            
        case RMCharacterEmotionSleepy: {
            break;
        }
            
        default:
            break;
    }
    return emotionHandler;
}

- (void)flipFromBackSide
{
    [self executeActions:@[
                           [RMRomotionAction actionWithLeftMotorPower:0.0 rightMotorPower:0.0 tiltMotorPower:-1.0 forDuration:2.0 robot:self.robot],
                           [RMRomotionAction actionWithLeftMotorPower:-1.0 rightMotorPower:-1.0 tiltMotorPower:0.0 forDuration:0.45 robot:self.robot]
                           ]];
}

- (void)flipFromFrontSide
{
    [self executeActions:@[
                           [RMRomotionAction actionWithLeftMotorPower:0.0 rightMotorPower:0.0 tiltMotorPower:1.0 forDuration:2.0 robot:self.robot],
                           [RMRomotionAction actionWithLeftMotorPower:1.0 rightMotorPower:1.0 tiltMotorPower:0.0 forDuration:0.45 robot:self.robot]
                           ]];
}

- (void)sayNo
{
    [self executeActions:@[
                           [RMRomotionAction actionWithLeftMotorPower:0.75 rightMotorPower:-1.0 tiltMotorPower:0.0 forDuration:0.1 robot:self.robot],
                           [RMRomotionAction actionWithLeftMotorPower:-1.0 rightMotorPower:0.75 tiltMotorPower:0.0 forDuration:0.1 robot:self.robot],
                           [RMRomotionAction actionWithLeftMotorPower:0.75 rightMotorPower:-1.0 tiltMotorPower:0.0 forDuration:0.1 robot:self.robot],
                           [RMRomotionAction actionWithLeftMotorPower:-1.0 rightMotorPower:0.75 tiltMotorPower:0.0 forDuration:0.1 robot:self.robot],
                           [RMRomotionAction actionWithLeftMotorPower:0.75 rightMotorPower:-1.0 tiltMotorPower:0.0 forDuration:0.1 robot:self.robot],
                           [RMRomotionAction actionWithLeftMotorPower:-1.0 rightMotorPower:0.75 tiltMotorPower:0.0 forDuration:0.1 robot:self.robot],
                           ]];
}

@end
