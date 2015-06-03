//
//  RMFavoriteColorRobotController.h
//  Romo
//

#import "RMActivityRobotController.h"

@interface RMFavoriteColorRobotController : RMActivityRobotController

@end

extern NSString *const favoriteColorKnowledgeKey;

/**
 Hues must be this close to Romo's favorite hue to trigger
 On [0.0, 0.5] where 0.0 is the exact hue, 0.5 is any hue
 since all hues are within 0.5 away from each other, modulo 1.0
 */
extern float const favoriteHueWidth;