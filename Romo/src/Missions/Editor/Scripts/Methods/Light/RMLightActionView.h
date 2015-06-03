//
//  RMLightActionView
//  Romo
//

#import "RMActionView.h"

typedef enum {
    RMLightActionViewStateOn,
    RMLightActionViewStateOff,
    RMLightActionViewStateBlink,
} RMLightActionViewState;

@interface RMLightActionView : RMActionView

@property (nonatomic) RMLightActionViewState state;

@end