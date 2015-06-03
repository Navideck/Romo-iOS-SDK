//
//  RMUnlockable.m
//  Romo
//

#import "RMUnlockable.h"
#import "RMAction.h"
#import "RMEvent.h"
#import "RMActionRuntime.h"

NSString *const RMRomoRateAppKey = @"RMRomoRateAppKey";
NSString *const RMRepeatUnlockedKey = @"RMRepeatUnlockedKey";

@interface RMUnlockable ()

@property (nonatomic, readwrite) RMUnlockableType type;
@property (nonatomic, readwrite) id value;
@property (nonatomic, readwrite, getter=isPresented) BOOL presented;

@end

@implementation RMUnlockable

- (id)initWithDictionary:(NSDictionary *)dictionary
{
    self = [super init];
    if (self) {
        id value;
        if ((value = dictionary[@"action"])) {
            self.type = RMUnlockableAction;
            if ([value[@"isScripted"] boolValue]) {
                value = [[RMAction alloc] initWithDictionary:value];
            } else {
                RMAction *actionWithParameters = [[RMAction alloc] initWithDictionary:value];
                RMAction *action = [RMAction actionWithSelector:value[@"selector"] parameterValues:nil locked:NO deletable:YES];
                action.parameters = actionWithParameters.parameters;
                value = action;
            }
        } else if ((value = dictionary[@"event"])) {
            self.type = RMUnlockableEvent;
            RMEvent *event = [[RMEvent alloc] initWithName:value];
            value = event;
        } else if ((value = dictionary[@"mission"])) {
            self.type = RMUnlockableMission;
        } else if ((value = dictionary[@"chapter"])) {
            self.type = RMUnlockableChapter;
        } else if ((value = dictionary[@"expression"])) {
            self.type = RMUnlockableExpression;
        } else {
            self.type = RMUnlockableOther;
            value = dictionary[@"other"];
        }
        self.value = value;
        
        BOOL presented = (dictionary[@"presented"] == nil || [dictionary[@"presented"] boolValue]);
        self.presented = presented;
    }
    return self;
}

- (id)initWithType:(RMUnlockableType)type value:(id)value
{
    self = [super init];
    if (self) {
        self.type = type;
        self.value = value;
    }
    return self;
}

+ (id)unlockableWithExpression:(RMCharacterExpression)expression
{
    return [[RMUnlockable alloc] initWithType:RMUnlockableExpression value:@(expression)];
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<RMUnlockable>(%@: %@)",
            self.type == RMUnlockableChapter ? @"Chapter" : self.type == RMUnlockableAction ? @"Action" : self.type == RMUnlockableMission ? @"Mission" :
            self.type == RMUnlockableExpression ? @"Expression" :
            self.type == RMUnlockableEvent ? @"Event" : @"Other",
            self.value];
}

@end
