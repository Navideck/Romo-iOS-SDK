//
//  RMEquilibrioception.h
//  Romo
//

#import <Romo/RMCore.h>

@protocol RMEquilibrioceptionDelegate;

typedef enum {
    RMRobotOrientationUpright   = 1,
    RMRobotOrientationFrontSide = 2,
    RMRobotOrientationBackSide  = 3,
    RMRobotOrientationLeftSide  = 4,
    RMRobotOrientationRightSide = 5,
} RMRobotOrientation;

@interface RMEquilibrioception : NSObject

@property (nonatomic, weak) id<RMEquilibrioceptionDelegate> delegate;
@property (nonatomic, readonly) RMRobotOrientation orientation;
@property (nonatomic, weak) RMCoreRobot<RobotMotionProtocol, HeadTiltProtocol, DriveProtocol> *robot;
@property (nonatomic) BOOL isDizzy;

@end

@protocol RMEquilibrioceptionDelegate <NSObject>

@optional

- (void)robotDidDetectPickup;
- (void)robotDidDetectPutDown;
- (void)robotDidFlipToOrientation:(RMRobotOrientation)orientation;
- (void)robotDidDetectShake;
- (void)robotDidStartClimbing;

@end

extern NSString *const RMRobotDidFlipToOrientationNotification;
extern NSString *const RMRobotDidStartClimbingNotification;
