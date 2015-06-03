//
//  CommandSubscriber.h
//  Romo
//

#import "RMSubscriber.h"
#import "RMCommandService.h"
#import "RMCommandMessage.h"

@interface RMCommandSubscriber : RMSubscriber <RMSocketDelegate>

+ (RMCommandSubscriber *)subscriberWithService:(RMCommandService *)service;

- (void)sendTankSlidersLeft:(float)left right:(float)right;
- (void)sendDpadSector:(RMDpadSector)sector;
- (void)sendJoystickDistance:(float)distance angle:(float)angle;
- (void)sendTiltMotorPower:(float)tiltMotorPower;
- (void)sendExpression:(RMCharacterExpression)expression;
- (void)sendTakePicture;

@end
