//
//  RMAction.h
//  Romo
//

#import <Foundation/Foundation.h>
#import "RMParameter.h"

@interface RMAction : NSObject

/** Title, e.g. "Record a video" */
@property (nonatomic, readonly) NSString *title;

/** Concise title, e.g. "Video" */
@property (nonatomic, readonly) NSString *shortTitle;

/** The library that this action lives in */
@property (nonatomic, readonly) NSString *library;

/** Parameters for this action */
@property (nonatomic, strong) NSArray *parameters;

/** A selector for the Obj-C representation in the API, e.g. "driveWithSpeed:forDuration:" */
@property (nonatomic, readonly) NSString *selector;

/** Dictionary-representation of a action */
@property (nonatomic, readonly) NSDictionary *dictionary;

/** The selector with the parameter names, e.g. "driveWithSpeed:(speed)speed forDuration:(duration)duration" */
@property (nonatomic, readonly) NSString *fullSelector;

/** Scripted actions run a nested script rather than a single action */
@property (nonatomic, readonly, getter=isScripted) BOOL scripted;

/** If scripted, an array of the scripted actions */
@property (nonatomic, readonly, strong) NSArray *scriptActions;

/** The total number available of this action */
@property (nonatomic) int availableCount;

/** If locked, parameters can't be edited */
@property (nonatomic, readonly, getter=isLocked) BOOL locked;

/** Defaults to YES */
@property (nonatomic, readonly, getter=isDeletable) BOOL deletable;

/** Given a properly-keyed dictionary, builds an action  */
- (RMAction *)initWithDictionary:(NSDictionary *)actionDictionary;

/** Given a path to a serialized script and a title, builds a scripted action */
- (RMAction *)initWithScriptTitle:(NSString *)title shortTitle:(NSString *)shortTitle availableCount:(int)availableCount;

/** Given the selector for an action and the desired parameter values, builds an action */
+ (RMAction *)actionWithSelector:(NSString *)selector parameterValues:(NSArray *)parameterValues locked:(BOOL)locked deletable:(BOOL)deletable;

- (NSDictionary *)dictionarySerialization;

/**
 Tries to merge the two actions into one
 e.g. "Turn clockwise 40°" then "Turn clockwise 50°" merges into "Turn clockwise 90°"
 returns YES if they were collapsed, NO if not
*/
- (BOOL)mergeWithAction:(RMAction *)action;

- (RMParameter *)parameterForType:(RMParameterType)type;

@end
