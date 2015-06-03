//
//  RMRomoteControlService.h
//  Romo
//

#import "RMService.h"
#import "RMSocket.h"

@protocol RMRemoteControlServiceDelegate <NSObject>

- (void)didReceivePicture:(UIImage *)picture;
- (void)remoteExpressionAnimationDidStart;
- (void)remoteExpressionAnimationDidFinish;
- (void)robotDidFlipOver;

@end

@interface RMRemoteControlService : RMService <RMSocketDelegate>

@property (nonatomic, weak) id<RMRemoteControlServiceDelegate> delegate;

+ (RMRemoteControlService *)service;

@end
