//
//  RMRomoteDriveExpressionButton.m
//

#import "RMRomoteDriveExpressionButton.h"
#import "UIColor+RMColor.h"

@implementation RMRomoteDriveExpressionButton

+ (id)buttonWithExpression:(RMCharacterExpression)expression
{
    RMRomoteDriveExpressionButton* button = [[RMRomoteDriveExpressionButton alloc] initWithFrame:CGRectMake(0, 0, 44, 44)];
    button.expression = expression;
    return button;
}

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.showsTitle = NO;
        self.canToggle = NO;
        self.exclusiveTouch = YES;
    }
    return self;
}

- (void)setHighlighted:(BOOL)highlighted
{
    super.highlighted = highlighted;
    
    self.backgroundColor = [UIColor romoWhite];
    self.imageView.alpha = highlighted ? 0.65 : 1.0;
}

- (void)setTitle:(NSString *)title {
    super.title = title;
    _titleLabel.text = title;
    
    self.expression = _expression;
    
//    [self setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    
    _titleLabel.textColor = [UIColor whiteColor];
    _titleLabel.shadowColor = [UIColor colorWithWhite:0 alpha:.4];
    _titleLabel.shadowOffset = CGSizeMake(0, 0.5);
}

- (void)setExpression:(RMCharacterExpression)expression
{
    _expression = expression;
    
    UIImage* expressionIcon = [UIImage imageNamed:[NSString stringWithFormat:@"R3UI-Expression-%d.png",expression]];
    [self setImage:expressionIcon forState:UIControlStateNormal];
    [self setImage:expressionIcon forState:UIControlStateHighlighted];
}

@end
