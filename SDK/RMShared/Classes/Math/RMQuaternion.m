//
//  RMQuaternion.m
//  Romo
//

#import "RMQuaternion.h"

/* --Private Interface-- */
@interface RMQuaternion()
{
}
@end

/* --Class Implementation-- */
@implementation RMQuaternion

- (id) init
{
    // init superclass
    self = [super init];
    
    if (self)
    {
        // do stuff
    }
    
    return self;
}

- (void) dealloc
{
}

+ (id) quaternionWithW:(double)w X:(double)x Y:(double)y Z:(double)z
{
    // the instance we're creating
    RMQuaternion *theInstance;
    
    // initalize
    theInstance = [[[self class] alloc] init];
    
    // copy quaternion parameters
    CMQuaternion q;
    q.w = w;
    q.x = x;
    q.y = y;
    q.z = z;
    
    theInstance.q = q;
    
    // return instantiated quaternion
    return theInstance;
}

+ (id) quaternionWithQ:(CMQuaternion)q
{
    // the instance we're creating
    RMQuaternion *theInstance;
    
    // initalize
    theInstance = [[[self class] alloc] init];
    
    // copy quaternion parameters
    theInstance.q = q;
    
    // return instantiated quaternion
    return theInstance;
}

- (void) setQuaternionParametersW:(double)w X:(double)x Y:(double)y Z:(double)z
{
    CMQuaternion q;
    
    q.w = w;
    q.x = x;
    q.y = y;
    q.z = z;
    
    self.q = q;
}

+ (double) magnitudeOfQuaternion:(CMQuaternion)q;
{
    return sqrt(q.w * q.w +
                q.x * q.x +
                q.y * q.y +
                q.z * q.z);
}

+ (CMQuaternion) normalizeQuaternion:(CMQuaternion)q
{
    double magnitude = [RMQuaternion magnitudeOfQuaternion:q];
    
    q.w /= magnitude;
    q.x /= magnitude;
    q.y /= magnitude;
    q.z /= magnitude;
    
    return q;
}

+ (CMQuaternion) conjugateQuaternion:(CMQuaternion)q
{
    q.x = -q.x;
    q.y = -q.y;
    q.z = -q.z;
    
    return q;
}

+ (CMQuaternion) inverseQuaternion:(CMQuaternion)q
{
    q =[RMQuaternion normalizeQuaternion:q];
    
    return [RMQuaternion conjugateQuaternion:(CMQuaternion)q];
}

+ (CMQuaternion) quaternionMultiply:(CMQuaternion)q1 Times:(CMQuaternion)q2
{
    CMQuaternion q3;
    
    q3.w = q1.w*q2.w - q1.x*q2.x - q1.y*q2.y - q1.z*q2.z;
    q3.x = q1.w*q2.x + q1.x*q2.w + q1.y*q2.z - q1.z*q2.y;
    q3.y = q1.w*q2.y - q1.x*q2.z + q1.y*q2.w + q1.z*q2.x;
    q3.z = q1.w*q2.z + q1.x*q2.y - q1.y*q2.x + q1.z*q2.w;

    return q3;
}

+ (CMQuaternion) scalarMultiply:(CMQuaternion)q Times:(float)s
{
    q.w *= s;
    q.x *= s;
    q.y *= s;
    q.z *= s;

    return q;
}

// find difference between two quaternions (q1 - q0)
+ (CMQuaternion) differenceFromQuaternion:(CMQuaternion)q0
                             ToQuaternion:(CMQuaternion)q1
{
    // take conjugate of starting quaternion
    q0 = [RMQuaternion conjugateQuaternion:q0];
    
    // find quaternion to get to ending quaternion (q1)
    return [RMQuaternion quaternionMultiply:q1 Times:q0];
}

+ (RMEulerAngles) getEulerAnglesFromQuaternion:(CMQuaternion)q
{
    RMEulerAngles euler;
    
    q = [RMQuaternion normalizeQuaternion: q];
    
    double test = q.y * q.z + q.x * q.w;
    
    // if singularity at north pole...
    if (test > 0.4999)  // 0.4999 corresponds to ~88 degrees
    {
        euler.yaw = 2 * atan2(q.y, q.w);
        euler.pitch = M_PI/2;
        euler.roll = 0;
        return euler;
    }
    
    // if singularity at south pole...
    if (test < -0.4999) // 0.499 corresponds to ~88 degrees
    {
        euler.yaw = -2 * atan2(q.y, q.w);
        euler.pitch = - M_PI/2;
        euler.roll = 0;
        return euler;
    }
    
    // otherwise:
    double sqx = q.x * q.x;
    double sqy = q.y * q.y;
    double sqz = q.z * q.z;
    
    euler.yaw = (float)atan2(2 * q.z * q.w - 2* q.y * q.x, 1 - 2 * sqz -
                              2 * sqx);
    
    euler.pitch = (float)asin(2 * test);

    euler.roll = (float)atan2(2 * q.y * q.w - 2 * q.z * q.x, 1 - 2 * sqy -
                               2 * sqx);
    return euler;
}

+(CMQuaternion) getQuaternionFromEulerAnglesRollDeg:(float)roll
                                            PitchDeg:(float)pitch
                                              YawDeg:(float)yaw
{
    return([self getQuaternionFromEulerAnglesRollRad:DEG2RAD(roll)
                                            PitchRad:DEG2RAD(pitch)
                                              YawRad:DEG2RAD(yaw) ] );
}

+ (CMQuaternion) getQuaternionFromEulerAnglesRollRad:(float)roll
                                            PitchRad:(float)pitch
                                              YawRad:(float)yaw
{
    CMQuaternion q;
    
    double cy = cos(yaw/2);
    double sy = sin(yaw/2);
    double cp = cos(pitch/2);
    double sp = sin(pitch/2);
    double cr = cos(roll/2);
    double sr = sin(roll/2);
    
    q.w = (cy * cp * cr) - (sy * sp * sr);
    q.x = (cy * cr * sp) - (sy * cp * sr);
    q.y = (cy * cp * sr) + (sy * cr * sp);
    q.z = (cy * sp * sr) + (cp * cr * sy);
    
    return q;
}

@end