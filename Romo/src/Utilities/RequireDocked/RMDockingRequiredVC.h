//
//  RMDockingRequiredVC.h
//  Romo
//

#import <UIKit/UIKit.h>

@protocol RMDockingRequiredVCDelegate;

@interface RMDockingRequiredVC : UIViewController

@property (nonatomic, weak) id<RMDockingRequiredVCDelegate> delegate;
@property (nonatomic) BOOL showsDismissButton;
@property (nonatomic) BOOL showsPurchaseButton;

@end

@protocol RMDockingRequiredVCDelegate <NSObject>

- (void)dockingRequiredVCDidDock:(RMDockingRequiredVC *)dockingRequiredVC;
- (void)dockingRequiredVCDidDismiss:(RMDockingRequiredVC *)dockingRequiredVC;

@end

extern NSString *const RMRomoControlAppStoreURL;