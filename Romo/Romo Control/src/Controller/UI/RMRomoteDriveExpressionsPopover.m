//
//  RMRomoteDriveExpressionsPopover.m
//

#import "RMRomoteDriveExpressionsPopover.h"
#import "UIView+Additions.h"
#import "UIColor+RMColor.h"

@implementation RMRomoteDriveExpressionsPopover

+ (id)expressionsPopover
{
    return [[RMRomoteDriveExpressionsPopover alloc] initWithFrame:CGRectMake(0, 0, [UIScreen mainScreen].bounds.size.width, 78)];
}

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor colorWithWhite:0 alpha:.35];

        NSArray *expressions = [NSArray arrayWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"DriveExpressionPopover" ofType:@"plist"]];
        for (int i = 0; i < expressions.count; i++) {
            NSDictionary* expression = expressions[i];
            RMRomoteDriveExpressionButton *expressionButton = [RMRomoteDriveExpressionButton buttonWithExpression:((NSNumber *)expression[@"expression"]).intValue];
            expressionButton.showsTitle = YES;
            expressionButton.title = expression[@"title"];
            expressionButton.left = 64*i + 16;
            expressionButton.top = 8;
            [expressionButton addTarget:self.popoverDelegate action:@selector(didTouchExpressionsPopoverFace:) forControlEvents:UIControlEventTouchUpInside];
            [self addSubview:expressionButton];
        }
        
        CGFloat contentWidth = (expressions.count-1)*64 + 44 + 2*16;
        if (contentWidth < self.width) {
            contentWidth = self.width;
        }
        self.contentSize = CGSizeMake(contentWidth, self.height);
        self.showsVerticalScrollIndicator = NO;
        self.alwaysBounceHorizontal = NO;
        _enabled = YES;
    }
    return self;
}

- (void)setFrame:(CGRect)frame {
    super.frame = frame;
    [self flashScrollIndicators];
}

- (void)setEnabled:(BOOL)enabled {
    if (enabled != _enabled) {
        [UIView animateWithDuration:0.25
                         animations:^{
                             for (UIView* subview in self.subviews) {
                                 subview.alpha = enabled ? 1.0 : 0.25;
                                 subview.userInteractionEnabled = enabled;
                             }
                         }];
    }
    _enabled = enabled;
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    CGFloat x = [[touches anyObject] locationInView:self].x;
    for (RMRomoteDriveExpressionButton* expression in self.subviews) {
        if ([expression isKindOfClass:[RMRomoteDriveExpressionButton class]]) {
            if (x > expression.left && x < expression.right) {
                [self.popoverDelegate didTouchExpressionsPopoverFace:expression];
                return;
            }
        }
    }
}

@end
