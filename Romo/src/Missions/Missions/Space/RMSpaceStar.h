#import <UIKit/UIKit.h>
#import "RMSpaceObject.h"

@interface RMSpaceStar : RMSpaceObject

/** Generates a star with a random relative size & brightness */
+ (id)randomStar;
+ (NSArray *)generateRandomSpaceStarsWithCount:(NSUInteger)count;

@end
