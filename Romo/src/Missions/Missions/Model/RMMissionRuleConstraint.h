//
//  RMMissionRuleConstraint.h
//  Romo
//

#import <Foundation/Foundation.h>

@class RMAction;
@class RMMissionRuleValue;

typedef enum {
    RMMissionConstraintComparisonEqual              = '=',
    RMMissionConstraintComparisonLessThanOrEqual    = '<',
    RMMissionConstraintComparisonGreaterThanOrEqual = '>',
    RMMissionConstraintComparisonApproximatelyEqual = '~',
    RMMissionConstraintComparisonOpposite           = '!',
} RMMissionConstraintComparisonType;

@interface RMMissionRuleConstraint : NSObject

/** RMMissionRuleValue or a literal NSNumber speed value */
@property (nonatomic, readonly, strong) id leftValue;
@property (nonatomic, readonly, strong) id rightValue;

/** How the left value should be compared to the right value */
@property (nonatomic, readonly) RMMissionConstraintComparisonType comparisonType;

/** Whether or not this constraint needs a action for its left or right value */
@property (nonatomic, readonly) BOOL needsLeftInput;
@property (nonatomic, readonly) BOOL needsRightInput;

/** If needsLeft/RightInput is true, the appropriate actions must be provided to correctly check validity */
@property (nonatomic, strong) RMAction *leftInput;
@property (nonatomic, strong) RMAction *rightInput;

/** When given the necessary left and/or right inputs, this flag is set */
@property (nonatomic, readonly) BOOL isValid;

/**
 Builds a constraint from a dictionary of the following form:
 @"leftValue" => left value
 @"rightValue" => right value
 @"comparisonType" => @"=" | @"<" | @">" | @"~"

 Values should be RMMissionRuleValues or literals
 e.g. a RMMissionRuleValue representing speed could be compared to another RMMissionRuleValue or a literal NSNumber speed value
 e.g. "speedValue > @(10)" or "speedValue ~ previousSpeedValue"
 */
- (id)initWithDictionary:(NSDictionary *)dictionary;

@end
