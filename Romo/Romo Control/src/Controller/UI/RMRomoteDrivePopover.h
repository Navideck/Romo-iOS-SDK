//
//  RMRomoteDrivePopover.h
//  Romo
//

#import "RMRomoteDriveButton.h"

@protocol RMRomoteDrivePopoverDelegate <NSObject>

- (void)didTouchPopoverButton:(RMRomoteDriveButton *)button;

@end

@interface RMRomoteDrivePopover : UIView

@property (nonatomic, weak) id<RMRomoteDrivePopoverDelegate> delegate;
@property (nonatomic, strong) NSString* title;
@property (nonatomic, strong) RMRomoteDrivePopover* previousPopover;

- (id)initWithTitle:(NSString *)title previousPopover:(RMRomoteDrivePopover *)previousPopover;

@end
