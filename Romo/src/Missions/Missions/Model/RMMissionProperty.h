//
//  RMMissionProperty.h
//  Romo
//

#import <Foundation/Foundation.h>

@interface RMMissionProperty : NSObject

/**
 n properties must match one of the following types of comparisons,
 where [minCount ≤ n ≤ maxCount]
 */

/** Actions with this name */
@property (nonatomic, readonly) NSString *actionName;

/** Actions in this library */
@property (nonatomic, readonly) NSString *library;

/** Total number of actions */
@property (nonatomic, readonly) BOOL count;

/**
 The bounds on how many actions must match the library or action
 -1 implies no bound
 Defaults to -1
 */
@property (nonatomic, readonly) int minimumCount;
@property (nonatomic, readonly) int maximumCount;

/**
 Creates a rule from a dictionary of the following form:
 @"action" => @"actionSelector:"
 - OR -
 @"library" => @"LibraryName"
 - OR -
 @"count" => NSNumber boolean
 
 Optional:
 @"minCount" => NSNumber integer
 @"maxCount" => NSNumber integer
 
 Examples:
 - 2 Drive actions
 - 1 to 3 "makeAFace:" actions
 */
- (id)initWithDictionary:(NSDictionary *)dictionary;

/**
 Checks to see if this property is matched by the set of actions
 Provide all actions in the user's script when checking for validity
 */
- (BOOL)matchesActions:(NSArray *)actions;

@end
