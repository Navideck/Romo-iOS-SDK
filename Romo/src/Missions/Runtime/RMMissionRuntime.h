//
//  RMMissionRuntime.h
//  Romo
//

#import <Foundation/Foundation.h>

@class RMRomo;

typedef enum {
    RMUserTrainedActionInvalid,
    RMUserTrainedActionRomotionTango,
    RMUserTrainedActionRomotionTangoWithMusic,
    RMUserTrainedActionDriveInACircle,
    RMUserTrainedActionDriveInASquare,
    RMUserTrainedActionNo,
    RMUserTrainedActionPoke,
    RMUserTrainedActionTickleChin,
    RMUserTrainedActionTickleNose,
    RMUserTrainedActionTickleForehead,
    RMUserTrainedActionPickedUp,
    RMUserTrainedActionPutDown,
    RMUserTrainedActionLoudSound,
} RMUserTrainedAction;

@interface RMMissionRuntime : NSObject

/**
 Given a valid Romo object and an action type, tries to run the user-created action
 Runs completion(finished) when done; finished is NO if the user hasn't trained that script yet or if something goes wrong
 */
+ (void)runUserTrainedAction:(RMUserTrainedAction)action onRomo:(RMRomo *)Romo completion:(void (^)(BOOL finished))completion;

+ (void)stopRunning;

@end
