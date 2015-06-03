//
//  RMTiltActionView
//  Romo
//

#import "RMTiltActionView.h"
#import <QuartzCore/QuartzCore.h>
#import "UIView+Additions.h"
#import "UIFont+RMFont.h"

@interface RMTiltActionView ()

@property (nonatomic) float angle;

@property (nonatomic, strong) UIImageView *angleBackground;
@property (nonatomic, strong) UIImageView *robot;
@property (nonatomic, strong) UIImageView *phone;
@property (nonatomic, strong) UIImageView *dashedLine;

@end

@implementation RMTiltActionView

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        _angleBackground = [[UIImageView alloc] initWithImage:[UIImage smartImageNamed:@"tiltAngleBackground.png"]];
        
        _robot = [[UIImageView alloc] initWithImage:[UIImage smartImageNamed:@"baseTiltBig.png"]];
        [self.contentView addSubview:self.robot];
        
        _phone = [[UIImageView alloc] initWithImage:[UIImage smartImageNamed:@"iPhoneTiltBig.png"]];
        self.phone.layer.anchorPoint = CGPointMake(0.5, 1.0);
        [self.contentView addSubview:self.phone];
        
        _dashedLine = [[UIImageView alloc] initWithImage:[UIImage smartImageNamed:@"tiltDash.png"]];
        self.dashedLine.layer.anchorPoint = self.phone.layer.anchorPoint;
        self.dashedLine.alpha = 0.75;
        self.dashedLine.frame = (CGRect){(self.contentView.width - self.dashedLine.image.size.width) / 2, self.contentView.height - 138, self.dashedLine.image.size};
        [self.contentView insertSubview:self.dashedLine belowSubview:self.phone];
        
        _angleBackground = [[UIImageView alloc] initWithImage:[UIImage smartImageNamed:@"tiltAngleBackground.png"]];
        
        [self layoutForEditing:NO];
    }
    return self;
}

- (void)setParameters:(NSArray *)parameters
{
    super.parameters = parameters;
    
    for (RMParameter *parameter in parameters) {
        if (parameter.type == RMParameterAngle) {
            self.angle = [parameter.value floatValue];
        }
    }
}

- (void)willLayoutForEditing:(BOOL)editing
{
    [super willLayoutForEditing:editing];
    
    self.angle = _angle;
    
    if (editing) {
        [self.dashedLine removeFromSuperview];
        [self.contentView insertSubview:self.angleBackground belowSubview:self.robot];
    }
}

- (void)setEditing:(BOOL)editing
{
    super.editing = editing;
    
    [self layoutForEditing:editing];
}

- (void)layoutForEditing:(BOOL)editing
{
    CGFloat w = self.contentView.width;
    
    [self stopAnimating];
    self.phone.transform = CGAffineTransformIdentity;
    
    if (editing) {
        self.phone.frame = (CGRect){(w - self.phone.image.size.width)/2 + 20, (self.contentView.height - self.phone.image.size.height)/2 - 40, self.phone.image.size};
        self.robot.frame = (CGRect){(w - self.robot.image.size.width)/2 + 20, self.phone.top + 170, self.robot.image.size};
        self.angle = _angle;
        
        CGSize s = self.angleBackground.image.size;
        self.angleBackground.frame = (CGRect){(w - s.width)/2 - 16, (self.contentView.height - s.height)/2 - 52, s};
        self.angleBackground.alpha = 1.0;
        
    } else {
        self.robot.frame = CGRectMake((w - 164)/2, self.contentView.height - 41, 164, 74);
        self.phone.frame = CGRectMake((w - 13)/2, self.contentView.height - 136, 13, 111);
        
        CGSize s = self.angleBackground.image.size;
        self.angleBackground.frame = CGRectMake((w - 0.5 * s.width)/2 - 8, (self.contentView.height - 0.5 * s.height) / 2, 0.5 * s.width, 0.5 * s.height);
        
        self.angleBackground.alpha = 0.0;
    }
}

- (void)didLayoutForEditing:(BOOL)editing
{
    [super didLayoutForEditing:editing];
    
    if (!editing) {
        self.angle = _angle;
        [self startAnimating];
        [self.angleBackground removeFromSuperview];
        [self.contentView insertSubview:self.dashedLine belowSubview:self.phone];
    }
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    [self touchesMoved:touches withEvent:event];
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
    CGPoint touchLocation = [[touches anyObject] locationInView:self];
    
    BOOL adjustsAngle = self.isEditing && (touchLocation.y < self.robot.top + 10) && (touchLocation.y > 90);
    if (adjustsAngle) {
        CGPoint anchor = CGPointMake(self.width / 2, self.phone.bottom);
        CGFloat dx = touchLocation.x - anchor.x;
        CGFloat dy = anchor.y - touchLocation.y;
        float angle = atan2f(dy, dx) * 180 / M_PI;
        self.angle = angle;
    }
}

- (void)setNoddingYes:(BOOL)noddingYes
{
    if (noddingYes != _noddingYes) {
        _noddingYes = noddingYes;
        
        if (noddingYes) {
            [self.dashedLine removeFromSuperview];
            self.phone.height -= 10;
            self.phone.top += 10;
        }
    }
}

- (void)startAnimating
{
    // 130° -> 70°
    if (!self.phone.layer.animationKeys.count) {
        if (self.isNoddingYes) {
            [UIView animateWithDuration:0.5 delay:0.75 options:0
                             animations:^{
                                 self.phone.transform = CGAffineTransformMakeRotation((5 * M_PI)/180.0);
                             } completion:^(BOOL finished) {
                                 if (finished) {
                                     [UIView animateWithDuration:0.5
                                                      animations:^{
                                                          self.phone.transform = CGAffineTransformMakeRotation((-15 * M_PI)/180.0);
                                                      } completion:^(BOOL finished) {
                                                          if (finished) {
                                                              [UIView animateWithDuration:0.5
                                                                               animations:^{
                                                                                   self.phone.transform = CGAffineTransformMakeRotation(0);
                                                                               } completion:^(BOOL finished) {
                                                                                   if (finished) {
                                                                                       [UIView animateWithDuration:0.5
                                                                                                        animations:^{
                                                                                                            self.phone.transform = CGAffineTransformMakeRotation((-10 * M_PI)/180.0);
                                                                                                        } completion:^(BOOL finished) {
                                                                                                            if (finished) {
                                                                                                                [self startAnimating];
                                                                                                            }
                                                                                                        }];
                                                                                   }
                                                                               }];
                                                          }
                                                      }];
                                 }
                             }];
        } else {
            self.phone.transform = CGAffineTransformMakeRotation((-40 * M_PI)/180.0);
            [UIView animateWithDuration:2.75 delay:0 options:UIViewAnimationOptionRepeat | UIViewAnimationOptionAutoreverse
                             animations:^{
                                 self.phone.transform = CGAffineTransformMakeRotation((20 * M_PI)/180.0);
                             } completion:nil];
        }
    }
}

- (void)stopAnimating
{
    [self.phone.layer removeAllAnimations];
}

#pragma mark - Private Methods

- (void)setAngle:(float)angle
{
    angle = MAX(70, MIN(angle, 135));
    _angle = angle;
    
    CGFloat phoneAngleOffset = 90.0 - angle;
    self.dashedLine.transform = CGAffineTransformMakeRotation((phoneAngleOffset * M_PI)/180.0);
    
    if (self.isEditing) {
        self.phone.transform = CGAffineTransformMakeRotation((phoneAngleOffset * M_PI)/180.0);
    }
    
    self.subtitle = [NSString stringWithFormat:@"%d°",(int)angle];
    
    for (RMParameter *parameter in self.parameters) {
        if (parameter.type == RMParameterAngle) {
            parameter.value = @(angle);
        }
    }
}

@end
