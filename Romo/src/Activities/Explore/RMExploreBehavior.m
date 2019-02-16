//
//  RMExploreRobotController.m
//  Romo
//

#import "RMExploreBehavior.h"
#import <Romo/RMDispatchTimer.h>
#import <Romo/RMMath.h>
#import <Romo/RMCircleMath.h>
#import "RMAppDelegate.h"
#import "RMStasisVirtualSensor.h"
#import "RMRomo.h"
#import "RMEvent.h"
#import "RMEquilibrioception.h"
#import <Romo/UIDevice+Romo.h>

static const float exploreLoopFrequencyFastDevice = 30.0; // Hz
static const float exploreLoopFrequencySlowDevice = 20.0; // Hz

static const float bumpTimeoutDelay = 0.85; // sec

//#define EXPLORE_WITH_EXPRESSIONS

typedef enum {
    RMBehaviorRandomBounceStateDrive,
    RMBehaviorRandomBounceStateDriveDwell,
    RMBehaviorRandomBounceStateBackup,
    RMBehaviorRandomBounceStateBackupDwell,
    RMBehaviorRandomBounceStateTurn,
    RMBehaviorRandomBounceStateIdle,
    RMBehaviorRandomBounceStateStuck
} RMBehaviorRandomBounceState;

@interface RMExploreBehavior ()

@property (nonatomic, strong) RMDispatchTimer *exploreLoopTimer;
@property (nonatomic) RMBehaviorRandomBounceState randomBounceState;

@property (nonatomic, strong) NSTimer *startDelayTimer;

@property (nonatomic, getter=isBumped) BOOL bumped;
@property (nonatomic, strong) NSTimer *bumpTimeoutTimer;

@property (nonatomic, getter=isExploring, readwrite) BOOL exploring;

@end

@implementation RMExploreBehavior

- (id)init
{
    self = [super init];
    if (self) {
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(stopExploring)
                                                     name:UIApplicationDidEnterBackgroundNotification
                                                   object:nil];

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(robotDidStartClimbing)
                                                     name:RMRobotDidStartClimbingNotification
                                                   object:nil];
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Public Methods

- (void)startExploring
{
    if (!self.startDelayTimer && self.Romo.robot && !self.isExploring) {
        self.exploring = YES;
        self.bumped = NO;

        // Prevent rapid start/stop/start sequences by delaying start commands by a bit
        self.startDelayTimer = [NSTimer scheduledTimerWithTimeInterval:0.25
                                                                target:self
                                                              selector:@selector(_startExploring)
                                                              userInfo:nil
                                                               repeats:NO];
    }
}

- (void)stopExploring
{
    if (self.startDelayTimer) {
        // If we just called start, cancel that request
        [self.startDelayTimer invalidate];
        self.startDelayTimer = nil;
        self.exploring = NO;
    } else if (self.isExploring) {
        [self.exploreLoopTimer stopRunning];
        
        [self.Romo.character lookAtDefault];
#ifdef EXPLORE_WITH_EXPRESSIONS
        self.Romo.character.emotion = RMCharacterEmotionHappy;
#endif
        
        self.exploring = NO;
    }
}

#pragma mark - Explore

- (void)_startExploring
{
    [self.startDelayTimer invalidate];
    self.startDelayTimer = nil;
    
    [self.Romo.robot tiltToAngle:110.0 completion:nil];
    
    self.randomBounceState = RMBehaviorRandomBounceStateDrive;
    [self.exploreLoopTimer startRunning];
}

- (void)explore
{
    const float kDriveSpeedNormal = RM_MAX_DRIVE_SPEED;
    const float kBackupSpeedNormal = 0.3;
    
    const float kDriveTimeMin = 0.5;                // s
    const float kDriveTimeout = 8.0;                // s
    const float kBackupTimeout = 1.25;              // s
    const float kIdleTimeout = 10.0;                // s
    
    const float kBaseTurnAngle = 80.0;              // degrees
    const float kTurnAngleAdder = 120.0;            // degrees
    
    static double driveTimeMin;                     // s
    static double driveTimeout;                     // s
    static double backupTimeout;                    // s
    static double idleTimeout;                      // s
    
    static float driveSpeed = kDriveSpeedNormal;    // s
    static float backupSpeed = kBackupSpeedNormal;  // s
    
    double now = currentTime();
    int turnDirection = CW;
    
    static int count = 0;
    count++;
    
    BOOL shouldLookAround = (count > self.exploreLoopTimer.frequency * 1.5 + arc4random() % (int)(self.exploreLoopTimer.frequency * 8));
    if (self.Romo.RomoCanLook && self.randomBounceState != RMBehaviorRandomBounceStateTurn && shouldLookAround) {
        // Look in a random direction
        int seed = arc4random() % 100;
        if (seed < 20) {
            // Look to the side
            float randomX = randFloat() * 2.0 - 1.0;
            float randomY = randFloat() * 0.25;
            float randomZ = randFloat();
            [self.Romo.character lookAtPoint:RMPoint3DMake(randomX, randomY, randomZ) animated:YES];
        } else if (seed < 50) {
            // Look up
            float randomZ = randFloat() / 3.0;
            [self.Romo.character lookAtPoint:RMPoint3DMake(0.0, -0.55, randomZ) animated:YES];
        } else if (seed < 80) {
            // Look down
            float randomY = 0.25 + randFloat() * 0.55;
            [self.Romo.character lookAtPoint:RMPoint3DMake(0.0, randomY, 0.25) animated:YES];
        } else {
            // Look ahead
            [self.Romo.character lookAtDefault];
        }
        count = 0;
    }
    
    if (!self.Romo.RomoCanDrive) {
        return;
    }
        
    switch (self.randomBounceState) {
        case RMBehaviorRandomBounceStateDrive:
            // drive straight forward
            [self.Romo.robot driveForwardWithSpeed:driveSpeed];
            driveTimeMin = now + kDriveTimeMin;
            driveTimeout = now + kDriveTimeout;
            self.randomBounceState = RMBehaviorRandomBounceStateDriveDwell;
            
#ifdef EXPLORE_WITH_EXPRESSIONS
            if (randFloat() < 0.25) {
                // Some of the time, make a face
                int seed = arc4random() % 100;
                if (seed < 5) {
                    self.Romo.character.expression = RMCharacterExpressionHappy;
                } else if (seed < 10) {
                    self.Romo.character.expression = RMCharacterExpressionLove;
                } else if (seed < 15) {
                    self.Romo.character.expression = RMCharacterExpressionWee;
                } else if (seed < 20) {
                    self.Romo.character.expression = RMCharacterExpressionYippee;
                } else if (seed < 21) {
                    self.Romo.character.expression = RMCharacterExpressionWant;
                } else if (seed < 22) {
                    self.Romo.character.expression = RMCharacterExpressionProud;
                }
                self.Romo.character.emotion = RMCharacterEmotionHappy;
            }
#endif
            
            break;
            
        case RMBehaviorRandomBounceStateDriveDwell:
            // drive until robot hits something (or time limit is reached)
            if (now > driveTimeMin && (self.stasisVirtualSensor.isInStasis || self.isBumped || now > driveTimeout)) {
                backupSpeed = kBackupSpeedNormal;
                self.randomBounceState = RMBehaviorRandomBounceStateBackup;
            }
            break;
            
        case RMBehaviorRandomBounceStateBackup:
            // drive straight back
            [self.Romo.robot driveBackwardWithSpeed:backupSpeed];
            backupTimeout = now + kBackupTimeout;
            self.randomBounceState = RMBehaviorRandomBounceStateBackupDwell;
            
#ifdef EXPLORE_WITH_EXPRESSIONS
            if (randFloat() < 0.05) {
                self.Romo.character.emotion = RMCharacterEmotionSad;
            }
#endif
            break;
            
        case RMBehaviorRandomBounceStateBackupDwell: {
            // drive until robot is moving freely (or time limit is reached)
            if ((!self.stasisVirtualSensor.isInStasis && !self.isBumped) || (now > backupTimeout)) {
                self.randomBounceState = RMBehaviorRandomBounceStateTurn;
            }
            break;
        }
            
        case RMBehaviorRandomBounceStateTurn: {
            // turn in a random direction through a constrained random angle
            if (randFloat() < 0.5) {
                turnDirection = CCW;
            }
            [self.Romo.character lookAtPoint:RMPoint3DMake(turnDirection * 1.0, 0.0, 0.45) animated:YES];
            [self.Romo.robot turnByAngle:turnDirection * (kBaseTurnAngle + (kTurnAngleAdder * randFloat()))
                              withRadius:RM_DRIVE_RADIUS_TURN_IN_PLACE
                         finishingAction:RMCoreTurnFinishingActionStopDriving
                              completion:^(BOOL success, float heading){
                                  if (success) {
                                      // a successful turn indicates likely freedom
                                      [self.Romo.character lookAtPoint:RMPoint3DMake(0.0, 0.0, 0.45) animated:YES];
                                      driveSpeed = kDriveSpeedNormal;
                                      self.randomBounceState = RMBehaviorRandomBounceStateDrive;
                                  } else {
                                      // tilt in a random way (maybe this shift in the center-
                                      // of-gravity will help free the robot)
                                      self.randomBounceState = RMBehaviorRandomBounceStateStuck;
                                  }
                              }];
            
#ifdef EXPLORE_WITH_EXPRESSIONS
            if (randFloat() < 0.15) {
                // Some of the time, make a face
                int seed = arc4random() % 100;
                if (seed < 33) {
                    self.Romo.character.expression = RMCharacterExpressionPonder;
                } else if (seed < 66) {
                    self.Romo.character.expression = RMCharacterExpressionCurious;
                } else {
                    self.Romo.character.expression = RMCharacterExpressionLookingAround;
                }
                
                if (randFloat() < 0.05) {
                    self.Romo.character.emotion = RMCharacterEmotionExcited;
                } else {
                    self.Romo.character.emotion = RMCharacterEmotionCurious;
                }
            }
#endif
            
            // wait in this states until turnByAngle gets called back
            idleTimeout = now + kIdleTimeout;
            self.randomBounceState = RMBehaviorRandomBounceStateIdle;
            break;
        }
            
        case RMBehaviorRandomBounceStateIdle: {
#ifdef EXPLORE_WITH_EXPRESSIONS
            if (randFloat() < 0.3) {
                self.Romo.character.emotion = RMCharacterEmotionHappy;
            }
#endif
            
            // normally something else with change the state and get us out
            // of here (but there is a timeout in case that doesn't happen)
            if (now > idleTimeout) {
                self.randomBounceState = RMBehaviorRandomBounceStateDrive;
            }
            break;
        }
            
        case RMBehaviorRandomBounceStateStuck: {
            // if we got here the robot has been unsuccessful in freeing itself,
            // so temporarily crank up the drive speed in an effort to get free
            if (randFloat() < 0.8) {
                backupSpeed = RM_MAX_DRIVE_SPEED;
                self.randomBounceState = RMBehaviorRandomBounceStateBackup;
                
#ifdef EXPLORE_WITH_EXPRESSIONS
                if (randFloat() < 0.2) {
                    // some of the time, make a facial reaction
                    int seed = arc4random() % 100;
                    if (seed < 20) {
                        self.Romo.character.expression = RMCharacterExpressionAngry;
                    } else if (seed < 40) {
                        self.Romo.character.expression = RMCharacterExpressionSmack;
                    } else if (seed < 60) {
                        self.Romo.character.expression = RMCharacterExpressionStruggling;
                    } else if (seed < 80) {
                        self.Romo.character.expression = RMCharacterExpressionLookingAround;
                    } else if (seed < 90) {
                        self.Romo.character.expression = RMCharacterExpressionSniff;
                    } else {
                        self.Romo.character.expression = RMCharacterExpressionExhausted;
                    }
                    
                    if (randFloat() < 0.35) {
                        self.Romo.character.emotion = RMCharacterEmotionBewildered;
                    }
                }
#endif
            } else {
                driveSpeed = RM_MAX_DRIVE_SPEED;
                self.randomBounceState = RMBehaviorRandomBounceStateDrive;
            }
            break;
        }
    }
}

- (void)robotDidStartClimbing
{
    dispatch_async(dispatch_get_main_queue(), ^{
        self.bumped = YES;
        
        self.randomBounceState = RMBehaviorRandomBounceStateStuck;
        
        [self.bumpTimeoutTimer invalidate];
        self.bumpTimeoutTimer = [NSTimer scheduledTimerWithTimeInterval:bumpTimeoutDelay
                                                                 target:self
                                                               selector:@selector(bumpTimedOut)
                                                               userInfo:nil
                                                                repeats:NO];
    });
}

- (void)bumpTimedOut
{
    self.bumped = NO;
    self.bumpTimeoutTimer = nil;
}

#pragma mark - Private Properties

- (RMDispatchTimer *)exploreLoopTimer
{
    if (!_exploreLoopTimer) {
        float frequency = [UIDevice currentDevice].isFastDevice ? exploreLoopFrequencyFastDevice : exploreLoopFrequencySlowDevice;
        _exploreLoopTimer = [[RMDispatchTimer alloc] initWithName:@"com.romotive.Explore" frequency:frequency];
        
        __weak RMExploreBehavior *weakSelf = self;
        _exploreLoopTimer.eventHandler = ^{
            [weakSelf explore];
        };
    }
    return _exploreLoopTimer;
}

@end
