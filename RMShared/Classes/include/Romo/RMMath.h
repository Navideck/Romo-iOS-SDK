//==============================================================================
//                             _
//                            | | (_)
//   _ __ ___  _ __ ___   ___ | |_ ___   _____
//  | '__/ _ \| '_ ` _ \ / _ \| __| \ \ / / _ \
//  | | | (_) | | | | | | (_) | |_| |\ V /  __/
//  |_|  \___/|_| |_| |_|\___/ \__|_| \_/ \___|
//
//==============================================================================
//
//  RMMath.h
//  RMCore
//
//
//==============================================================================
/** @file RMMath.h
 @brief A collection of useful mathematical functions and macros
 */
#import <Foundation/Foundation.h>
#import <mach/mach_time.h>

/// Functionality for drawing a pseudo-random float in the range [0.0, 1.0]
#define ARC4RANDOM_MAX 0x100000000
#define randFloat() ((double)arc4random() / ARC4RANDOM_MAX)

/// Convert radians to degrees and vice-versa
#define RAD2DEG(radians) ((radians) * (180.0 / M_PI))
#define DEG2RAD(degrees) ((degrees) * (M_PI / 180.0))

/// Test if two integers have the same sign
#define SAME_SIGN(x, y) ((x >= 0) ^ (y < 0))

/// Test if a number is positive or negative
#define SIGN(x) ((x >= 0) ? 1 : -1)

/// Ensure that a value lies within a given range
#define CLAMP(min, val, max) (MAX(min, MIN(val, max)))

// Returns the most accurate current time possible
//------------------------------------------------------------------------------
static inline double currentTime()
{
    const double kOneBillion = 1E9;
    static mach_timebase_info_data_t s_timebase_info;
    
    if (s_timebase_info.denom == 0) {
        (void)mach_timebase_info(&s_timebase_info);
    }
    
    // mach_absolute_time() returns billionth of seconds,
    // so divide by one million to get milliseconds
    return (double)(mach_absolute_time() * s_timebase_info.numer) / (double)(kOneBillion * s_timebase_info.denom);
}

@interface RMMath : NSObject

/**
 Re-maps a number from one range to another. Does not constrain values to 
 within the range, because out-of-range values are often intended and useful.
 
 @param x The value to map
 @param in_min The lower bound of the value's current range
 @param in_max The upper bound of the value's current range
 @param out_min The lower bound of the value's desired range
 @param out_max The upper bound of the value's desired range
 
 @returns The mapped value
 */
+ (float) map:(float)x
          min:(float)in_min
          max:(float)in_max
      out_min:(float)out_min
      out_max:(float)out_max;

/**
 Draws from a normal distribution with a given mean and standard distribution
 
 @param mu The desired mean for the distribution
 @param sigma The desired standard deviation for the distribution
 
@returns The value drawn from the distribution
 */
+ (float)drawFromNormal:(float)mu
                 stdDev:(float)sigma;

/**
 Rounds value to the nearest round
 e.g. [RMMath round:16 toNearest:5] => 15
 e.g. [RMMath round:5 toNearest:3] => 6
 */
+ (float)round:(float)value toNearest:(float)round;

/**
 Generates a random float between two values (inclusive)
 */
+ (float)randFloatWithLowerBound:(float)lowerBound
                   andUpperBound:(float)upperBound;

@end
