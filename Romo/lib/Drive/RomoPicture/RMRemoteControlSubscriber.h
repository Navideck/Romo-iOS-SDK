//
//  RMRomoteControlSubscriber.h
//  Romo
//

#import "RMSubscriber.h"
#import "RMRemoteControlService.h"
#import "RMSocket.h"

@interface RMRemoteControlSubscriber : RMSubscriber <RMSocketDelegate>

+ (RMRemoteControlSubscriber *)subscriberWithService:(RMRemoteControlService *)service;

- (void)sendPicture:(UIImage *)picture;
- (void)sendExpressionDidStart;
- (void)sendExpressionDidFinish;
- (void)sendRobotDidFlipOver;

@end
