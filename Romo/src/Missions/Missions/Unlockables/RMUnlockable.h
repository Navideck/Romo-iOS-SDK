//
//  RMUnlockable.h
//  Romo
//

#import <Foundation/Foundation.h>
#import <Romo/RMCharacter.h>

typedef enum {
    RMUnlockableAction,
    RMUnlockableEvent,
    RMUnlockableMission,
    RMUnlockableChapter,
    RMUnlockableExpression,
    RMUnlockableOther, // RMRomoRateAppKey, ...
} RMUnlockableType;

@interface RMUnlockable : NSObject

@property (nonatomic, readonly) RMUnlockableType type;
@property (nonatomic, readonly) id value;
@property (nonatomic, readonly, getter=isPresented) BOOL presented;

/**
 Examples:
 @{ @"mission" -> @"1-2" }
 @{ @"action" -> @"Title of Action" }
 @{ @"event" -> @"RMEventType" }
 @{ @"chapter" -> @"2" }
 @{ @"expression" -> @(RMCharacterExpressionLaugh) }
 @{ @"other" -> RMRomoRateAppKey }
 */
- (id)initWithDictionary:(NSDictionary *)dictionary;

- (id)initWithType:(RMUnlockableType)type value:(id)value;

/** One-liners for common unlockables */
+ (id)unlockableWithExpression:(RMCharacterExpression)expression;

@end

/**
 NSUserDefault-stored key noting whether we've prompted the user to rate
 */
extern NSString *const RMRomoRateAppKey;

/**
 NSUserDefault-stored key noting whether the user has unlocked Repeat capability
 */
extern NSString *const RMRepeatUnlockedKey;
