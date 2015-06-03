//
//  RMExtendedScrollView.m
//  Romo
//

#import "RMExtendedScrollView.h"
#import "UIView+Additions.h"

@implementation RMExtendedScrollView

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event
{
    BOOL pointInsideScrollView = [self.extendedScrollView pointInside:point withEvent:event];
    BOOL horizontallyValid = self.extendsHorizontally ? (point.x < self.extendedScrollView.left || point.x > self.extendedScrollView.right) : pointInsideScrollView;
    BOOL verticallyValid = self.extendsVertically ? (point.y >= self.extendedScrollView.top && point.y < self.extendedScrollView.bottom) : pointInsideScrollView;
    
    if ([self pointInside:point withEvent:event] && verticallyValid && horizontallyValid) {
        return self.extendedScrollView;
    }
    
    return [super hitTest:point withEvent:event];
}

@end
