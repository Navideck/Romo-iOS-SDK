//
//  RMMissionRule.h
//  Romo
//

#import <Foundation/Foundation.h>

@class RMAction;
@class RMMissionRuleConstraint;

@interface RMMissionRule : NSObject

/** The action to match */
@property (nonatomic, copy, readonly) NSString *action;

/** The constraints on this action and its parameters */
@property (nonatomic, copy, readonly) NSArray *constraints;

/** Provide all actions in the user's script when checking for validity */
@property (nonatomic, strong) NSArray *actions;

/**
 Creates a rule from a dictionary of the following form:
 @"action" => @"actionSelector:"
 @"constraints" => array of RMMissionContraint dictionary representations
 OR 
 @"wildcard" => YES which accepts any non-empty action
 */
- (id)initWithDictionary:(NSDictionary *)dictionary;

/**
 Compares the type and parameters to see if this rule is valid
 */
- (BOOL)matchesAction:(RMAction *)action;

@end
