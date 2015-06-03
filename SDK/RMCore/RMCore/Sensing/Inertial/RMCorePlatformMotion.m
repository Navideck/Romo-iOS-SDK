//
//  RMCorePlatformMotion.m
//  RMCore
//

#import <CoreMotion/CMAttitude.h>
#import "RMCorePlatformMotion.h"
#import <RMShared/RMQuaternion.h>

@interface RMCorePlatformMotion()

@property (nonatomic) CMQuaternion referenceAttitude; // attitude of phone
                                                      // relative to fixed
                                                      // reference frame
@property (nonatomic) BOOL isDeviceTiltedBack;        // Device == iPhone
@property (nonatomic) BOOL isReferenceAttitudeSet;

@end

@implementation RMCorePlatformMotion

-(id) init
{
    self = [super init];
    
    if (self)
    {
        _isReferenceAttitudeSet = NO;
    }

    return self;
}

#pragma mark - Data Updaters

// received IMU data and calculate useful platform-based measurements
- (void)setFreshIMUData:(RMCoreIMUData)freshIMUData
{
    _freshIMUData = freshIMUData;
    
    [self updateYawRate];
    [self updateAccelerationVector];
    [self updateAttitude];
}

// calculated platform's yaw rate around axis parallel to gravity vector
//
// Warning: This assumes platform is on level ground.
- (void)updateYawRate
{
    RMCoreIMUData *IMU = &(_freshIMUData);         // convenience variable
    
    _yawRate = (float)((-IMU->gravity.x * IMU->rotationRate.x) +
                       (-IMU->gravity.y * IMU->rotationRate.y) +
                       (-IMU->gravity.z * IMU->rotationRate.z) );
}

// calculate platform's acceleration vector (gravity not included)
// Note: this all assumes that the platform is on flat ground, if it's not the
//       calculations will be off!
- (void)updateAccelerationVector
{
    // WARNING: All these calculations assume that the direction of the user
    //          acceleration is signed opposite to how Apple shows it on their
    //          diagram of the phone.  What seems like the correct signs have
    //          been determined empirically by looking at what data comes out of
    //          the IMU (user accel in the direction of the bottom of the phone
    //          (home button) is positive-y, towards the left (when looking at
    //          screen) is postive-x, towards the back of the phone is
    //          positive-z
    //
    //    NOTE: Apple's diagram signs do align with the signs that it gives when
    //          the IMU provides the gravity vector.
 
    RMCoreIMUData *IMU = &(_freshIMUData);         // convenience variable
    
    // aligned with axis orthogonal to the side of the robot (positive to the
    // platform's right)
    _acceleration.x = (float)(IMU->deviceAcceleration.x);

    // aligned with axis orthogonal to the front of the robot (postive to the
    // robot's front) !!! WARNING: This _may_ only be correct when the robot
    //                             is upright (normal use case) !!!
    _acceleration.y = (float)(((SIGN(IMU->gravity.z) *
                                (1 + IMU->gravity.y) * IMU->deviceAcceleration.y)) +
                              ((1 - fabsf(IMU->gravity.z) * IMU->deviceAcceleration.z) ) );
    
    // aligned with axis orthogonal to the bottom of robot (positive up)
    _acceleration.z = (float)((IMU->gravity.x * IMU->deviceAcceleration.x) +
                              (IMU->gravity.y * IMU->deviceAcceleration.y) +
                              (IMU->gravity.z * IMU->deviceAcceleration.z) );
}

// calculate platform's orientation in space
- (void)updateAttitude
{
    // find mobility platform's attitude (difference in phone's current
    // attitude from phone's reference attitude
    CMQuaternion attitudeQuaternion = [RMQuaternion
                               differenceFromQuaternion:self.referenceAttitude
                               ToQuaternion: self.freshIMUData.attitude ];
    
    // get mobility platform's attitude as Euler angles
    RMEulerAngles eulerAttitude = [RMQuaternion
                                   getEulerAnglesFromQuaternion:attitudeQuaternion ];
    
    // force pitch into "correct" [-180, 180] degree range (note: pitce it
    // naturally [-90, 90] but here roll and gravity direction are used to
    // estimate a user-friendly representation of pitch that extends to the
    // range [-180 180]
    if ((fabsf(eulerAttitude.roll) > M_PI_2) &&
       (fabs(self.freshIMUData.gravity.z) > fabs(self.freshIMUData.gravity.x)) )
    {
        // if the robot's roll shows > 90 degrees and the gravity vector is
        // more along the phone's Z-axis than X-axis then we estimate that
        // the robot has been rotated by more than 90 degrees about the pitch
        // axis, so extend the pitch up to +/-180 degrees.  If the gravity
        // strength axes are reversed then we estimat that the robot is
        // "actually" rolled and so the pitch is left unchanged (in reality,
        // pitch doesn't have much meaning when the robot is laying on its
        // side).
        
        // do pitch range extention with correct signs
        if (eulerAttitude.pitch > 0)
        {
            eulerAttitude.pitch = M_PI - eulerAttitude.pitch;
        }
        else
        {
            eulerAttitude.pitch = -M_PI - eulerAttitude.pitch;
        }
    }
    
    // convert to degrees for user friendliness
    _attitude.roll = RAD2DEG(eulerAttitude.roll);
    _attitude.pitch = RAD2DEG(eulerAttitude.pitch);
    _attitude.yaw = RAD2DEG(eulerAttitude.yaw);
}

#pragma mark - Helpers Methods

- (void)takeReferenceAttitude
{
    // Note: It's important that this method not be called before the IMU is
    // fully up and running or the reference attitude will end up with a garbage
    // value.  This is protected for in RMCore because the user accessible
    // method in RMCoreRobot*.m will only call this method if RobotMotion says
    // it's ready.
    
    if (self.isReferenceAttitudeSet == NO)
    {
        self.referenceAttitude = self.freshIMUData.attitude;

        self.isDeviceTiltedBack = YES;
        if (self.freshIMUData.gravity.z > 0)
        {
            _isDeviceTiltedBack = NO;
        }
        self.isReferenceAttitudeSet = YES;
    }
    else    
    {            
        // find device's current attitude in euler angles
        RMEulerAngles nowEulers = [RMQuaternion getEulerAnglesFromQuaternion:
                                               self.freshIMUData.attitude ];
        
        // covert existing reference attitude in euler angles
        RMEulerAngles referenceEulers = [RMQuaternion
                                         getEulerAnglesFromQuaternion:self.referenceAttitude ];
        
        // set phone's current tilt relative to vertical singularity
        BOOL isDeviceTiltedBackNow = YES;
        if (self.freshIMUData.gravity.z > 0)
        {
            isDeviceTiltedBackNow = NO;
        }
        
        // update current pitch as reference pitch (this makes mobility
        // platform's pitch zero
        referenceEulers.pitch = nowEulers.pitch;
        
        // if the phone's tilt relative to verticle singular has changed then
        // the reference roll and pitch need to be rotated 180 degress so that
        // the correct reference quaternion can be built
        if (isDeviceTiltedBackNow != _isDeviceTiltedBack)
        {
            referenceEulers.roll = referenceEulers.roll - M_PI;
            referenceEulers.yaw = referenceEulers.yaw - M_PI;
            _isDeviceTiltedBack = isDeviceTiltedBackNow;
        }
        
        // turn updated new reference attitude euler angles back into a quaternion
        RMQuaternion *newReference = [RMQuaternion quaternionWithQ:
                                            [RMQuaternion
                getQuaternionFromEulerAnglesRollRad:referenceEulers.roll
                                           PitchRad:referenceEulers.pitch
                                             YawRad:referenceEulers.yaw ] ];
        // store new reference quaternion
        _referenceAttitude = newReference.q;
    }
}

@end
