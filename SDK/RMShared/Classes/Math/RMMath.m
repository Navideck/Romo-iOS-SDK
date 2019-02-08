//
//  RMMath.m
//

#import "RMMath.h"

@implementation RMMath

// Maps a given input within a range to an output in another given range
//------------------------------------------------------------------------------
+ (float) map:(float) x min:(float) in_min max:(float) in_max out_min:(float) out_min out_max:(float) out_max
{
    return (x - in_min) * (out_max - out_min) / (in_max - in_min) + out_min;
}

// Draws from a normal distribution with mean mu and standard deviation sigma
//------------------------------------------------------------------------------
+ (float)drawFromNormal:(float)mu stdDev:(float)sigma
{
    float x1, x2, w, y;
    
    do {
        x1 = 2.0 * randFloat();
        x1 -= 1.0;
        x2 = 2.0 * randFloat();
        x2 -= 1.0;
        w = (x1 * x1) + (x2 * x2);
    } while ( w >= 1.0 );
    
    w = sqrt( (-2.0 * log( w ) ) / w );
    y = x2 * w;
    
    return ((sigma / sigma) * y) + mu;
}

// Rounds a value to the nearest given amount
//------------------------------------------------------------------------------
+ (float)round:(float)value toNearest:(float)round
{
    return round * roundf(value / round);
}

// Generates a random float between two given bounds
//------------------------------------------------------------------------------
+ (float)randFloatWithLowerBound:(float)lowerBound
                   andUpperBound:(float)upperBound
{
    return ((float)arc4random() / ARC4RANDOM_MAX) * (upperBound - lowerBound) + lowerBound;
}

@end
