//
//  RMRomoteDriveVC.h
//  RMRomoteDriveVC
//

#import "RMRomoteDriveTopBar.h"

@class RMPeer;

@protocol RMWiFiDriveRemoteVCDelegate;

@interface RMWiFiDriveRemoteVC : UIViewController

@property (nonatomic, weak) id<RMWiFiDriveRemoteVCDelegate> delegate;
@property (nonatomic, strong) RMPeer *remotePeer;

@end

@protocol RMWiFiDriveRemoteVCDelegate <NSObject>

- (void)dismissDriveVC:(RMWiFiDriveRemoteVC *)driveVC;

@end