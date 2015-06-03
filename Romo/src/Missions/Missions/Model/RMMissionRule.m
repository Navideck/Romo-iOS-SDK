//
//  RMMissionRule.m
//  Romo
//

#import "RMMissionRule.h"
#import "RMMissionRuleConstraint.h"
#import "RMMissionRuleValue.h"
#import "RMAction.h"

@interface RMMissionRule ()

@property (nonatomic, copy, readwrite) NSString *action;
@property (nonatomic, copy, readwrite) NSArray *constraints;
@property (nonatomic, getter=isWildcard) BOOL wildcard;

@end

@implementation RMMissionRule

- (id)initWithDictionary:(NSDictionary *)dictionary
{
    self = [super init];
    if (self) {
        BOOL wildcard = [dictionary[@"wildcard"] boolValue];
        if (wildcard) {
            self.wildcard = YES;
        } else {
            self.action = dictionary[@"action"];
            
            NSArray *constraintDictionaries = dictionary[@"constraints"];
            NSMutableArray *constraints = [NSMutableArray arrayWithCapacity:constraintDictionaries.count];
            for (NSDictionary *constraintDictionary in constraintDictionaries) {
                RMMissionRuleConstraint *constraint = [[RMMissionRuleConstraint alloc] initWithDictionary:constraintDictionary];
                [constraints addObject:constraint];
            }
            self.constraints = [NSArray arrayWithArray:constraints];
        }
    }
    return self;
}

- (BOOL)matchesAction:(RMAction *)action
{
    // Wildcard matches any action
    if (self.isWildcard && action) {
        return YES;
    }
    
    // Check to see that it's the right kind of action
    BOOL actionNameMatches = [action.fullSelector isEqualToString:self.action];
    
    // Check to see that the constraints are all valid
    BOOL constraintsAreValid = YES;
    for (RMMissionRuleConstraint *constraint in self.constraints) {
        
        // If the constraint needs to be compared against another action, provide that action
        if (constraint.needsLeftInput) {
            int indexOfLeftInput = ((RMMissionRuleValue *)constraint.leftValue).index;
            
            if (indexOfLeftInput == -1) {
                constraint.leftInput = action;
            } else if (self.actions.count > indexOfLeftInput && indexOfLeftInput >= 0) {
                constraint.leftInput = self.actions[indexOfLeftInput];
            } else {
                return NO;
            }
        }

        if (constraint.needsRightInput) {
            int indexOfRightInput = ((RMMissionRuleValue *)constraint.rightValue).index;
            
            if (indexOfRightInput == -1) {
                constraint.rightInput = action;
            } else if (self.actions.count > indexOfRightInput && indexOfRightInput >= 0) {
                constraint.rightInput = self.actions[indexOfRightInput];
            } else {
                return NO;
            }
        }
        constraintsAreValid &= constraint.isValid;
    }
    
    return actionNameMatches && constraintsAreValid;
}

- (void)setConstraints:(NSArray *)constraints
{
    _constraints = constraints;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<RMMissionRule: %@ must match %@ >",self.action, self.constraints];
}

@end
