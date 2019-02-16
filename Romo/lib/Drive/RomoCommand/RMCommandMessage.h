//
//  CommandMessage.h
//  Romo
//

#import "RMMessage.h"
#import <Romo/RMCharacter.h>
#import "RMJoystick.h"
#import "RMTankSlider.h"
#import "RMDpad.h"

typedef enum {
    COMMAND_ALL,
    COMMAND_DRIVE,
    COMMAND_TILT,
    COMMAND_EXPRESSION,
    COMMAND_PICTURE
} CommandType;

typedef enum {
    DRIVE_CONTROL_NONE,
    DRIVE_CONTROL_DPAD,
    DRIVE_CONTROL_JOY,
    DRIVE_CONTROL_TANK
} DriveControlType;

typedef struct {
    DriveControlType controlType;
    float leftSlider;
    float rightSlider;
    float distance;
    float angle;
    RMDpadSector sector;
} DriveControlParameters;

@interface RMCommandMessage : RMMessage

@property (nonatomic) DriveControlType controlType;
@property (nonatomic) float leftSlider;
@property (nonatomic) float rightSlider;
@property (nonatomic) float tiltMotorPower;
@property (nonatomic) float distance;
@property (nonatomic) float angle;
@property (nonatomic) RMDpadSector sector;
@property (nonatomic) RMCharacterExpression expression;

+ (RMCommandMessage *)messageWithDriveParameters:(DriveControlParameters)parameters;
+ (RMCommandMessage *)messageWithTiltMotorPower:(float)tiltMotorPower;
+ (RMCommandMessage *)messageWithExpression:(RMCharacterExpression)expression;
+ (RMCommandMessage *)messageToTakePicture;

@end
