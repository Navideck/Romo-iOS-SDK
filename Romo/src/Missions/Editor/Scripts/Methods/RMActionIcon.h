//
//  RMActionIcon.h
//  Romo
//

#import <UIKit/UIKit.h>
#import "RMButtonIcon.h"

@class RMAction;

@interface RMActionIcon : RMButtonIcon

/** A badge showing how many of this action are available to be used */
@property (nonatomic) int availableCount;

- (RMActionIcon *)initWithAction:(RMAction *)action;

@end
