//
//  RMTracker.m
//  Romo
//
//  Created on 7/15/13.
//  Copyright (c) 2013 Romotive. All rights reserved.
//

#import "RMTracker.h"
#import "RMRomo.h"
#import <Romo/RMMath.h>
#import "RMOrientationConfidenceModel.h"
#import <Romo/UIDevice+Romo.h>

#define kLookScalarX -0.20
#define kLookScalarY -0.48
#define kSearchAngle 15

#define kMinimumFaceLocationDiscrepancyX 0.1
#define kMinimumFaceLocationDiscrepancyY 0.3

#define kInitialSearchSpeed 0.3
#define kSearchSpeed        0.4
#define kSearchTimeInterval 5.0

#ifdef DEBUG_TRACKER
#define trackerLog(string) DDLogVerbose(string)
#else
#define trackerLog(string)
#endif

NSString *const RMTracker_Face = @"FaceTracker";
NSString *const RMTracker_Motion = @"MotionTracker";

@interface RMTracker ()

@property (nonatomic, strong) RMFace *face;

@property (nonatomic, strong) NSString *activeTracker;
@property (nonatomic) double trackerStartPoint;
@property (nonatomic) double trackerConfidencePoint;
@property (nonatomic, strong) RMOrientationConfidenceModel *orientationModel;

@property (nonatomic, getter=isSearching) BOOL searching;
@property (nonatomic, getter=isTracking) BOOL tracking;

@property (nonatomic) BOOL isSlow;
@property (nonatomic) BOOL canTurn;
@property (nonatomic) float lastFaceLocation;

@property (nonatomic) double lastTrackerSearchTime;

@end

@implementation RMTracker

#pragma mark - Initialization
//------------------------------------------------------------------------------
-(id)init
{
    self = [super init];
    if (self) {
        trackerLog(@"init");
        _isSlow = ![[UIDevice currentDevice] isDockableTelepresenceDevice];
        _canTurn = YES;
        _activeTracker = nil;
        _searching = NO;
        _orientationModel = [[RMOrientationConfidenceModel alloc] init];

        _trackerConfidencePoint = 0.0;
        _trackerStartPoint = 0.0;

        _lastTrackerSearchTime = currentTime() - kSearchTimeInterval;
        _tracking = NO;
    }
    return self;
}

//------------------------------------------------------------------------------
-(void)dealloc
{
    trackerLog(@"dealloc");
    [self.orientationModel stop];

    _activeTracker = nil;
    _searching = NO;
    _orientationModel = nil;
}

#pragma mark - Tracking
//------------------------------------------------------------------------------
-(void)trackObject:(RMObject*)object
{
    if (self.searching) {
        if ([object isKindOfClass:[RMFace class]]) {
            [self.delegate didFindObject:RMTracker_Face];
        }
    }
    
    self.searching = NO;
    self.tracking = YES;
    trackerLog(@"Tracking object");

    if ([object isKindOfClass:[RMFace class]]) {
        // Initialize tracker if first invocation or not tracking anything
        if (!self.activeTracker || ![self.activeTracker isEqualToString:RMTracker_Face]) {
            [self initTrackerWithName:RMTracker_Face];
        }
        self.face = (RMFace *)object;

        // Keep eye contact
        [self lookAtObject:object];
        
        if (self.Romo.robot && self.Romo.RomoCanDrive) {
            // Y adaptive thresholding
            float errorY = ABS(self.face.location.y);
            if (errorY > kMinimumFaceLocationDiscrepancyY) {
                float tiltAngle = self.face.location.y * 22.5;
                
                if (self.Romo.robot.headAngle + tiltAngle < 85) {
                    [self.Romo.robot stopTilting];
                } else {
                    [self.Romo.robot tiltByAngle:tiltAngle
                                      completion:^(BOOL success) {
                                      }];
                }
            } else {
                [self.Romo.robot stopTilting];
            }
        }
        
        [self.Romo.robot stopDriving];
        // Don't do realtime turn tracking if we're a slow device
        if (self.isSlow) {
            return;
        }

        // Update confidence model
        if ([self.Romo.robot conformsToProtocol:@protocol(RobotMotionProtocol)]
            && ((RMCoreRobot<RobotMotionProtocol> *)self.Romo.robot).isRobotMotionReady) {
            RMCoreRobot<RobotMotionProtocol> *robot = (RMCoreRobot<RobotMotionProtocol> *)self.Romo.robot;

            CGFloat x = self.face.location.x;
            CGFloat y = self.face.location.y;
            CGFloat z = self.face.distance;

            CGFloat actualX = x * z/2.0;
            CGFloat actualY = y * z/2.0;

            RMPoint3D faceLocation = RMPoint3DMake(actualX, actualY, z);
            CGFloat theta = RAD2DEG(atan2f(-faceLocation.x, faceLocation.z));
            CGFloat heading = robot.platformAttitude.yaw;

            float objectLoc = fmodf(heading + theta, 360);
            while (objectLoc < 0) {
                objectLoc += 360;
            }
#ifdef DEBUG_TRACKER
            DDLogVerbose(@"Object seen at %f", objectLoc);
#endif
            [self.orientationModel objectSeenAt:objectLoc];
            self.lastFaceLocation = objectLoc;
        }

        // Realtime tracking
        if (self.Romo.RomoCanDrive && self.Romo.robot) {
            // X adaptive thresholding
            float errorX = ABS(self.face.location.x);
            float turnPower = errorX * .35;

            if (errorX > kMinimumFaceLocationDiscrepancyX) {
                if (self.face.location.x > 0) {
                    trackerLog(@"Realtime turning left");
                    [self.Romo.robot driveWithRadius:RM_DRIVE_RADIUS_TURN_IN_PLACE speed:-turnPower];
                } else {
                    trackerLog(@"Realtime turning right");
                    [self.Romo.robot driveWithRadius:RM_DRIVE_RADIUS_TURN_IN_PLACE speed:turnPower];
                }
            } else {
                trackerLog(@"Stopping turn");
                [self.Romo.robot stopDriving];
            }
        }
    } else if ([object isKindOfClass:[RMMotion class]]) {
        if (!self.activeTracker || ![self.activeTracker isEqualToString:RMTracker_Motion]) {
            [self initTrackerWithName:RMTracker_Motion];
        }
    }
}

//------------------------------------------------------------------------------
- (void)lookAtObject:(RMObject *)object
{
    if ([object isKindOfClass:[RMFace class]]) {
        RMFace *face = (RMFace *)object;

        if (self.Romo.RomoCanLook) {
            float zLookDist = (face.distance - 15.0)/(125.0 - 15.0);
            [self.Romo.character lookAtPoint:RMPoint3DMake(face.location.x * kLookScalarX,
                                                           face.location.y * kLookScalarY,
                                                           zLookDist)
                                    animated:NO];
        }
    }
}

//------------------------------------------------------------------------------
-(void)lostTrackOfObject
{
    trackerLog(@"Lost track of object");
    
    self.tracking = NO;
    [self.Romo.character lookAtDefault];
    [self.Romo.robot stopAllMotion];
    
    if (self.Romo.vision.isSlow) {
        if (self.canTurn && (ABS(self.face.location.x) > .2)) {
            float turnAngle = 0;
            if (self.face.location.x > 0) {
                turnAngle = kSearchAngle * -1;
#ifdef DEBUG_TRACKER
                DDLogVerbose(@"Turning right by %f", turnAngle * -1);
#endif
            } else {
                turnAngle = kSearchAngle;
#ifdef DEBUG_TRACKER
                DDLogVerbose(@"Turning left by %f", turnAngle);
#endif
            }
            self.canTurn = NO;
            if (self.Romo.RomoCanDrive) {
                [self.Romo.robot turnByAngle:turnAngle
                                  withRadius:RM_DRIVE_RADIUS_TURN_IN_PLACE
                                  completion:^(BOOL success, float heading) {
                                      self.canTurn = YES;
                                  }];
            }
        }
    } else {
        double timeNow = currentTime();
        if (self.Romo.robot && ((timeNow - self.lastTrackerSearchTime) > kSearchTimeInterval)) {
            double delayInSeconds = 1.0;
            dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
            dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
                if (!self.tracking && self.Romo.RomoCanDrive) {
                    self.lastTrackerSearchTime = currentTime();
                    int lastHeading = [self.orientationModel mostProbableLocation];
                    if (lastHeading >= 0) {
                        [self.Romo.robot turnToHeading:lastHeading
                                            withRadius:RM_DRIVE_RADIUS_TURN_IN_PLACE
                                                 speed:kInitialSearchSpeed
                                     forceShortestTurn:YES
                                       finishingAction:RMCoreTurnFinishingActionStopDriving
                                            completion:^(BOOL success, float heading) {
                                                [self resetTracker];
                                                // [self searchForObject];
                                            }];
                    }
                }
            });
        }
    }
}

#pragma mark - Private
//------------------------------------------------------------------------------
-(void)initTrackerWithName:(NSString *)name
{
    trackerLog(@"Initializing tracker");
    self.activeTracker = name;

    self.searching = NO;
    [self.Romo.robot stopAllMotion];

    if ([self.Romo.robot conformsToProtocol:@protocol(RobotMotionProtocol)]) {
        self.trackerStartPoint = ((RMCoreRobot<RobotMotionProtocol> *)self.Romo.robot).platformAttitude.yaw;
    }
}

//------------------------------------------------------------------------------
-(void)searchForObject
{
    if (!self.isTracking && self.Romo.RomoCanDrive) {
        self.searching = YES;
        trackerLog(@"Searching for object");

        RMCoreRobot<DriveProtocol, HeadTiltProtocol> *robot = (RMCoreRobot<DriveProtocol, HeadTiltProtocol> *)self.Romo.robot;
        [robot turnByAngle:kSearchAngle
                withRadius:RM_DRIVE_RADIUS_TURN_IN_PLACE
                completion:^(BOOL success, float heading) {
                    double delayInSeconds = 1.0;
                    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
                    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
                        if (!self.isTracking && self.Romo.RomoCanDrive) {
                            [robot turnByAngle:-(kSearchAngle*2)
                                    withRadius:RM_DRIVE_RADIUS_TURN_IN_PLACE
                                    completion:^(BOOL success, float heading) {
                                        double delayInSeconds = 1.5;
                                        dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
                                        dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
                                            if (!self.isTracking && self.Romo.RomoCanDrive) {
                                                [robot turnByAngle:kSearchAngle
                                                        withRadius:RM_DRIVE_RADIUS_TURN_IN_PLACE
                                                        completion:^(BOOL success, float heading) {
                                                            self.searching = NO;
                                                        }];
                                            }
                                        });
                                    }];
                        }
                    });
                }];
    }
    
}

//------------------------------------------------------------------------------
-(void)resetTracker
{
    trackerLog(@"Object was permanently lost");
    [self.delegate didLoseTrackOfObject:self.activeTracker];
    
    self.activeTracker = nil;
    self.searching = NO;
    self.tracking = NO;
    [self.orientationModel resetConfidences];
}

@end
