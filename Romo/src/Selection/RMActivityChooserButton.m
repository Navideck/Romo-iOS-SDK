//
//  RMActivityChooserButton.m
//  Romo
//


#import "RMActivityChooserButton.h"
#import "UIFont+RMFont.h"
#import "UIView+Additions.h"

@implementation RMActivityChooserButton

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
        [self addSubview:self.iconImageView];
        self.titleLabel.font = [UIFont largeFont];
        self.titleLabel.textColor = [UIColor whiteColor];
        self.titleLabel.size = CGSizeMake(150, self.height);
        self.titleLabel.adjustsFontSizeToFitWidth = YES;
        self.titleLabel.numberOfLines = 1;
        self.titleLabel.lineBreakMode = NSLineBreakByClipping;
    }
    return self;
}

- (void)setFrame:(CGRect)frame
{
    [super setFrame:frame];
    self.iconImageView.size = CGSizeMake(frame.size.height, frame.size.height);
    self.iconImageView.right = self.titleLabel.left + 20;
    self.titleEdgeInsets = UIEdgeInsetsMake(0, 50, 0, 0);
}

- (UIImageView *)iconImageView
{
    if (!_iconImageView) {
        _iconImageView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, self.frame.size.height, self.frame.size.height)];
    }
    return _iconImageView;
}

- (void)setTitle:(NSString *)title forState:(UIControlState)state
{
    [super setTitle:title forState:state];
}

@end
