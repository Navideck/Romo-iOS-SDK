//
//  RMRomotion.h
//  Romo
//

#import <Foundation/Foundation.h>
#import <Romo/RMCharacter.h>
#import <Romo/RMCore.h>
#import "RMRomotionAction.h"

@interface RMRomotion : NSObject

/** Shows the Romotion for the expression */
@property (nonatomic) RMCharacterExpression expression;

/** Applies a left, right, and tilt transform to all motor commands for the emotion */
@property (nonatomic) RMCharacterEmotion emotion;

/** The state of expression Romotions */
@property (nonatomic, readonly, getter=isRomoting) BOOL romoting;

/**
 The desired strength of am emotion Romotion
 A value of 0.0 turns emotion Romotions off
 A non-zero value indicates emotion Romotions are running
 On the range [0,1]
 */
@property (nonatomic) float intensity;

/** The robot to act on */
@property (nonatomic, weak) RMCoreRobot<DifferentialDriveProtocol, HeadTiltProtocol, RobotMotionProtocol> *robot;

- (void)flipFromBackSide;
- (void)flipFromFrontSide;
- (void)stopRomoting;
- (void)sayNo;

@end
