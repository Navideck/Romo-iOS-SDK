//
//  RMJoystick.m
//  Romo
//

#import "RMJoystick.h"
#import "UIView+Additions.h"
#import <Romo/RMMath.h>

@interface RMJoystick()

@property (nonatomic, strong) UIImageView *handle;

@end

@implementation RMJoystick

#pragma mark - Initializations --

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
//        UIImageView *backgroundView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"R3UI-JoystickBack.png"]];
        UIImageView *backgroundView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"joystick-bg"]];
        backgroundView.frame = self.bounds;
        backgroundView.contentMode = UIViewContentModeScaleAspectFill;
        backgroundView.alpha = 0.45;
        [self addSubview:backgroundView];
        
//        _handle = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"R3UI-JoystickBall.png"]];
        _handle = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"joystick-nub"]];
        self.handle.frame = CGRectMake(0, 0, 0.35 * self.width, 0.35 * self.width);
        self.handle.center = CGPointMake(self.width / 2, self.height / 2);
//        self.handle.alpha = 0.9;
        [self addSubview:self.handle];
    }
    return self;
}

#pragma mark - View Touch Events --

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    [self touchesMoved:touches withEvent:event];
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
    CGPoint touchLocation = [[touches anyObject] locationInView:self];

    CGFloat scale = self.width / 2;

    CGFloat dx = touchLocation.x - scale;
    CGFloat dy = touchLocation.y - scale;

    CGFloat angle = atan2f(-dy, dx);
    CGFloat distance = MIN(1.0, sqrtf(powf(dx, 2) + powf(dy, 2)) / scale);

    if (angle < 0) {
        angle += 2 * M_PI;
    }

    CGFloat handleScale = scale - (self.handle.width / 2);
    CGPoint handleCenter = CGPointMake(scale + handleScale * (distance * cosf(angle)), scale - handleScale * (distance * sinf(angle)));
    self.handle.center = handleCenter;

    [self.delegate joystick:self didMoveToAngle:RAD2DEG(angle) distance:distance];
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    [self.delegate joystick:self didMoveToAngle:0 distance:0];
    [UIView animateWithDuration:0.15
                     animations:^{
                         self.handle.center = CGPointMake(self.width / 2, self.height / 2);
                     }];
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
    [self touchesEnded:touches withEvent:event];
}

@end
