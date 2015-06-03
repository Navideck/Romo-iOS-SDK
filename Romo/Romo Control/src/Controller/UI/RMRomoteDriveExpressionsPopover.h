//
//  RMRomoteDriveExpressionsPopover.h
//

#import "RMRomoteDriveExpressionButton.h"

@protocol RMRomoteDriveExpressionsPopoverDelegate;

@interface RMRomoteDriveExpressionsPopover : UIScrollView

@property (nonatomic, weak) id<RMRomoteDriveExpressionsPopoverDelegate> popoverDelegate;
@property (nonatomic) BOOL enabled;

+ (id)expressionsPopover;

@end

@protocol RMRomoteDriveExpressionsPopoverDelegate <NSObject>

- (void)didTouchExpressionsPopoverFace:(id)face;

@end
