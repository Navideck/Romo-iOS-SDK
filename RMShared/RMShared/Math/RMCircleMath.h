//
//  RMCoreCircleMath.h
//  RMCore
//

//

#define CW      1
#define CCW     -1

#define MAX_CIRCLE_ANGLE    180
#define MIN_CIRCLE_ANGLE    -180

float circleSubtract(float a, float b);
float circleAdd(float a, float b);
float enforceCircularRange(float angle);