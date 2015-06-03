//
//  RMActivityBanner.h
//  Romo
//

#import <UIKit/UIKit.h>
#import "RMMission.h"

@interface RMActivityMotivation : NSObject

/**
 Returns a dictionary representing a prompt for the user to play an activity
 "question" -> an NSString to be asked to the user
 "yes" -> the affirmative answer
 "no" -> the negatory answer
 "mission" -> if motivated to play a mission, an RMMission; else nil
 "chapter" -> if motivated to play a chapter, an NSNumber-wrapped RMChapter; else nil
 */
+ (NSDictionary *)currentMotivation;

@end
