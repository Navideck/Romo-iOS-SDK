//
//  CommandService.h
//  Romo
//

#import "RMService.h"
#import "RMCommandMessage.h"
#import <Romo/RMCharacter.h>
#import "RMSocket.h"

@protocol RMCommandDelegate;

@interface RMCommandService : RMService <RMSocketDelegate>

@property (nonatomic, weak) id<RMCommandDelegate> delegate;

+ (RMCommandService *)service;

@end

@protocol RMCommandDelegate <NSObject>

@optional

- (void)commandReceivedWithDriveParameters:(DriveControlParameters)parameters;
- (void)commandReceivedWithTiltMotorPower:(float)tiltMotorPower;
- (void)commandReceivedWithExpression:(RMCharacterExpression)expression;
- (void)commandReceivedToTakePicture;

@end

