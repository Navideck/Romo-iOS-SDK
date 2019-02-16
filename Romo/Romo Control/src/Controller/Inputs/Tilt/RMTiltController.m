//
//  RMTiltController.h
//

#import "RMTiltController.h"
#import <Romo/RMMath.h>
#import "UIView+Additions.h"
#import "UIFont+RMFont.h"
#import "UIColor+RMColor.h"

#define MAX_SPEED 800.0
#define EDGE_HEIGHT 80.0

@interface RMTiltController () {
    CGFloat _previousY;
    CFAbsoluteTime _previousTime;
    NSTimer *_noMovementTimer;
    
    UILabel *_hintLabel;
}

- (void)noMovement;
- (BOOL)holdingAtEdge:(CGFloat)y;

@end

@implementation RMTiltController

- (void)dealloc
{
    [_noMovementTimer invalidate];
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{    
    _previousTime = currentTime();
    _previousY = [[touches anyObject] locationInView:self].y;
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
    [_noMovementTimer invalidate];
    CGFloat y = [[touches anyObject] locationInView:self].y;
    CFAbsoluteTime time = currentTime();
    
    if (![self holdingAtEdge:_previousY] || ![self holdingAtEdge:y]) {
        CGFloat velocity = (y - _previousY)/(time - _previousTime);
        velocity = MAX(MIN(velocity, MAX_SPEED), -MAX_SPEED);
        [self.delegate tiltWithVelocity:velocity/MAX_SPEED];
        
        _noMovementTimer = [NSTimer scheduledTimerWithTimeInterval:0.1 target:self selector:@selector(noMovement) userInfo:nil repeats:NO];
    }
    
    _previousY = y;
    _previousTime = time;
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    [_noMovementTimer invalidate];
    [self.delegate tiltWithVelocity:0];
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
    [self touchesEnded:touches withEvent:event];
}

- (void)noMovement {
    [_noMovementTimer invalidate];
    if ([self holdingAtEdge:_previousY]) {
        [self.delegate tiltWithVelocity:(_previousY < EDGE_HEIGHT + 20) ? -1.0 : 1.0];
    } else {
        [self.delegate tiltWithVelocity:0];
    }
}

- (BOOL)holdingAtEdge:(CGFloat)y {
    return (y < EDGE_HEIGHT || y > self.height - EDGE_HEIGHT);
}

- (void)setShowHint:(BOOL)showHint {
    _showHint = showHint;
    if (showHint) {
        if (!_hintLabel) {
            _hintLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 120, self.width - 40, 84)];
            _hintLabel.backgroundColor = [UIColor clearColor];
            _hintLabel.textColor = [UIColor romoWhite];
            _hintLabel.textAlignment = NSTextAlignmentCenter;
            _hintLabel.font = [UIFont voiceForRomoWithSize:34];
            _hintLabel.numberOfLines = 2;
            _hintLabel.layer.shadowColor = [UIColor romoBlack].CGColor;
            _hintLabel.layer.shadowOffset = CGSizeMake(0, 3);
            _hintLabel.layer.shadowOpacity = 1.0;
            _hintLabel.layer.shadowRadius = 5.0;
            _hintLabel.layer.shouldRasterize = YES;
            _hintLabel.layer.rasterizationScale = 2.0;
            _hintLabel.clipsToBounds = NO;
            _hintLabel.text = @"Swipe up & down\nTo look around!";
        }
        _hintLabel.alpha = 0.0;
        _hintLabel.transform = CGAffineTransformMakeScale(0.1, 0.1);
        [self addSubview:_hintLabel];
        
        [UIView animateWithDuration:0.25
                         animations:^{
                             self->_hintLabel.alpha = 1.0;
                             self->_hintLabel.transform = CGAffineTransformMakeScale(1.1, 1.1);
                         } completion:^(BOOL finished) {
                             [UIView animateWithDuration:0.25
                                              animations:^{
                                                  self->_hintLabel.transform = CGAffineTransformIdentity;
                                              }];
                         }];
        
    } else {
        [UIView animateWithDuration:0.25
                         animations:^{
                             self->_hintLabel.transform = CGAffineTransformMakeScale(1.1, 1.1);
                         } completion:^(BOOL finished) {
                             [UIView animateWithDuration:0.25
                                              animations:^{
                                                  self->_hintLabel.alpha = 0.0;
                                                  self->_hintLabel.transform = CGAffineTransformMakeScale(0.1, 0.1);
                                                  [self->_hintLabel removeFromSuperview];
                                              }];
                         }];
    }
}

@end
