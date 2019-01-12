//
//  CommandMessage.m
//  Romo
//

#import "RMCommandMessage.h"

#define KEY_TILT           @"key_tilt"
#define KEY_DRIVE_CONTROL  @"key_drive_control"
#define KEY_DRIVE_LEFT     @"key_drive_left"
#define KEY_DRIVE_RIGHT    @"key_drive_right"
#define KEY_DRIVE_DISTANCE @"key_drive_distance"
#define KEY_DRIVE_ANGLE    @"key_drive_angle"
#define KEY_DRIVE_SECTOR   @"key_drive_sector"
#define KEY_EXPRESSION     @"key_expression"

@interface RMCommandMessage ()
{
    
}

- (id)initWithTiltMotorPower:(float)tiltMotorPower
                 controlType:(DriveControlType)controlType
                  leftSlider:(float)driveLeft
                 rightSlider:(float)driveRight
                    distance:(float)driveSpeed
                       angle:(float)driveRadius
                 controlDpad:(RMDpadSector)sector
                  expression:(RMCharacterExpression)expression
                        type:(CommandType)type;
@end

@implementation RMCommandMessage

- (id)init
{
    return [self initWithContent:COMMAND_ALL];
}

- (id)initWithContent:(NSInteger)content
{
    return [self initWithTiltMotorPower:0.0
                            controlType:DRIVE_CONTROL_NONE
                             leftSlider:0.0
                            rightSlider:0.0
                               distance:0.0
                                  angle:0.0
                            controlDpad:RMDpadSectorNone
                             expression:RMCharacterExpressionNone
                                   type:(CommandType)content];
}

- (id)initWithTiltMotorPower:(float)tiltMotorPower
                 controlType:(DriveControlType)controlType
                  leftSlider:(float)leftSlider
                 rightSlider:(float)rightSlider
                    distance:(float)distance
                       angle:(float)angle
                 controlDpad:(RMDpadSector)sector
                  expression:(RMCharacterExpression)expression
                        type:(CommandType)type;
{
    if (self = [super initWithContent:type]) {
        _tiltMotorPower = tiltMotorPower;
        _controlType = controlType;
        _leftSlider = leftSlider;
        _rightSlider = rightSlider;
        _distance = distance;
        _angle = angle;
        _sector = sector;
        _expression = expression;
    }
    
    return self;
}

+ (RMCommandMessage *)messageWithTiltMotorPower:(float)tiltMotorPower
{
    return [[RMCommandMessage alloc] initWithTiltMotorPower:tiltMotorPower
                                                controlType:DRIVE_CONTROL_NONE
                                                 leftSlider:0.0
                                                rightSlider:0.0
                                                   distance:0.0
                                                      angle:0.0
                                                controlDpad:RMDpadSectorNone
                                                 expression:RMCharacterExpressionNone
                                                       type:COMMAND_TILT ];
}

+ (RMCommandMessage *)messageWithDriveParameters:(DriveControlParameters)parameters
{
    return [[RMCommandMessage alloc] initWithTiltMotorPower:0.0
                                                controlType:parameters.controlType
                                                 leftSlider:parameters.leftSlider
                                                rightSlider:parameters.rightSlider
                                                   distance:parameters.distance
                                                      angle:parameters.angle
                                                controlDpad:parameters.sector
                                                 expression:RMCharacterExpressionNone
                                                       type:COMMAND_DRIVE];
}

+ (RMCommandMessage *)messageWithExpression:(RMCharacterExpression)expression
{
    return [[RMCommandMessage alloc] initWithTiltMotorPower:0.0
                                                controlType:DRIVE_CONTROL_NONE
                                                 leftSlider:0.0
                                                rightSlider:0.0
                                                   distance:0.0
                                                      angle:0.0
                                                controlDpad:RMDpadSectorNone
                                                 expression:expression
                                                       type:COMMAND_EXPRESSION ];
}

+ (RMCommandMessage *)messageToTakePicture
{
    return [[RMCommandMessage alloc] initWithContent:COMMAND_PICTURE];
}

- (id)initWithCoder:(NSCoder *)coder
{
    if (self = [super initWithCoder:coder]) {
        _tiltMotorPower  = [coder decodeFloatForKey:KEY_TILT];
        _controlType     = (DriveControlType)[coder decodeIntegerForKey:KEY_DRIVE_CONTROL];
        _leftSlider      = [coder decodeFloatForKey:KEY_DRIVE_LEFT];
        _rightSlider     = [coder decodeFloatForKey:KEY_DRIVE_RIGHT];
        _distance        = [coder decodeFloatForKey:KEY_DRIVE_DISTANCE];
        _angle           = [coder decodeFloatForKey:KEY_DRIVE_ANGLE];
        _sector          = [coder decodeIntForKey:KEY_DRIVE_SECTOR];
        _expression      = (RMCharacterExpression)[coder decodeIntegerForKey:KEY_EXPRESSION];
    }
    
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [super encodeWithCoder:coder];
    [coder encodeFloat:_tiltMotorPower forKey:KEY_TILT];
    [coder encodeInteger:_controlType forKey:KEY_DRIVE_CONTROL];
    [coder encodeFloat:_leftSlider forKey:KEY_DRIVE_LEFT];
    [coder encodeFloat:_rightSlider forKey:KEY_DRIVE_RIGHT];
    [coder encodeFloat:_distance forKey:KEY_DRIVE_DISTANCE];
    [coder encodeFloat:_angle forKey:KEY_DRIVE_ANGLE];
    [coder encodeInteger:_sector forKey:KEY_DRIVE_SECTOR];
    [coder encodeInteger:_expression forKey:KEY_EXPRESSION];
}

@end
