//
//  RMRomoteDrivePopoverController.h
//  Romo
//

#import "RMRomoteDriveButton.h"
#import "RMRomoteDrivePopover.h"

@interface RMRomoteDrivePopoverController : UIViewController

@property (nonatomic, weak) id<RMRomoteDrivePopoverDelegate> delegate;
@property (nonatomic, strong) RMRomoteDrivePopover* popover;

- (id)initWithTitle:(NSString *)title;
- (void)presentPopoverWithTitle:(NSString *)title;
- (void)presentRootPopover;

@end
