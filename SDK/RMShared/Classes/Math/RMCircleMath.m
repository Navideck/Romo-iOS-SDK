//
//  RMCircleMath.m
//

#import "RMCircleMath.h"

// subtract two angles while making sure the results remains within the bounds
// of the a single cycle of the circle
// Note: assumes inputs are within MAX_CIRCLE/MIN_CIRCLE_ANGLE limits
float circleSubtract(float a, float b)
{
    return enforceCircularRange((a - b));
}

// add two angles while making sure the results remains within the bounds
// of the a single cycle of the circle
// Note: assumes inputs are within MAX_CIRCLE/MIN_CIRCLE_ANGLE limits
float circleAdd(float a, float b)
{
    return enforceCircularRange((a + b));
}

// take care of circle wrap-around (a and b are on the range
// [MIN_CIRCLE_ANGLE, MAX_CIRCLE_ANGLE])
// Note: assumes input angle <= 720 degrees
float enforceCircularRange(float angle)
{
    while (angle > MAX_CIRCLE_ANGLE) {angle -= 360;}
    while (angle < MIN_CIRCLE_ANGLE) {angle += 360;}

    return angle;
}