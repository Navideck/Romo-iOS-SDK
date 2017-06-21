//
//  RMQuaternion.h
//

#import <Foundation/Foundation.h>
#import <CoreMotion/CMAttitude.h>
#import "RMMath.h"

/* --Constants-- */
enum controlAxisNames
{
    ROLL,
    PITCH,
    YAW
};

/* --Data Types-- */
typedef struct
{
    float roll;
    float pitch;
    float yaw;
} RMEulerAngles;

/* --Class Interface-- */
@interface RMQuaternion : NSObject
{
}

/* --Public Properties-- */
@property (nonatomic) CMQuaternion q;

/* --Public Methods-- */

// factory methods to create an initialized quaternion
+ (id) quaternionWithW:(double)w X:(double)x Y:(double)y Z:(double)z;
+ (id) quaternionWithQ:(CMQuaternion)q;

- (id) init;                        // initialize
- (void) dealloc;                   // deallocate
- (void) setQuaternionParametersW:(double)w X:(double)x Y:(double)y Z:(double)z;

+ (double) magnitudeOfQuaternion:(CMQuaternion)q;             // find magnitude of quaternion
+ (CMQuaternion) normalizeQuaternion:(CMQuaternion)q;         // normalize quaternion
+ (CMQuaternion) conjugateQuaternion:(CMQuaternion)q;         // same as inverse for normalized quaternion
+ (CMQuaternion) inverseQuaternion:(CMQuaternion)q;           // ensures quaterion is normalized
+ (CMQuaternion) quaternionMultiply:(CMQuaternion)q1 Times:(CMQuaternion)q2;
+ (CMQuaternion) scalarMultiply:(CMQuaternion)q Times:(float)s;
+ (CMQuaternion) differenceFromQuaternion:(CMQuaternion)q0    // find difference between two quaternions (q1 - q0)
                             ToQuaternion:(CMQuaternion)q1;

+ (RMEulerAngles) getEulerAnglesFromQuaternion:(CMQuaternion)q; // find euler representation of quaternion

+ (CMQuaternion) getQuaternionFromEulerAnglesRollDeg:(float)roll
                                            PitchDeg:(float)pitch
                                              YawDeg:(float)yaw;

+ (CMQuaternion) getQuaternionFromEulerAnglesRollRad:(float)roll
                                            PitchRad:(float)pitch
                                              YawRad:(float)yaw;
@end
