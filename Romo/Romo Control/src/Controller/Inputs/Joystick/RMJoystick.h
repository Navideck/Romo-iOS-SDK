//
//  RMJoystick.h
//  Romo
//

#import <UIKit/UIKit.h>

@protocol RMJoystickDelegate;

@interface RMJoystick : UIView

@property (nonatomic, weak) id<RMJoystickDelegate> delegate;

@end

@protocol RMJoystickDelegate <NSObject>

- (void)joystick:(RMJoystick *)joystick didMoveToAngle:(float)angle distance:(float)distance;

@end