//
//  RMRomoteDriveButton.m
//

#import "RMRomoteDriveButton.h"
#import "UIView+Additions.h"
#import "UIFont+RMFont.h"
#import "UIColor+RMColor.h"

@implementation RMRomoteDriveButton

+ (id)buttonWithTitle:(NSString *)title
{
    RMRomoteDriveButton *button = [[RMRomoteDriveButton alloc] initWithFrame:CGRectMake(0, 0, 44, 44)];
    button.title = title;
    return button;
}

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor romoWhite];
        self.layer.borderWidth = 1;
        self.layer.borderColor = [UIColor romoGray].CGColor;
        self.layer.cornerRadius = self.width/2;
        self.clipsToBounds = NO;
        
        _titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(-8, 46, self.width + 16, 16)];
        _titleLabel.backgroundColor = [UIColor clearColor];
        _titleLabel.textAlignment = NSTextAlignmentCenter;
        _titleLabel.font = [UIFont romoBoldFontWithSize:12];
        _titleLabel.adjustsFontSizeToFitWidth = YES;
        _titleLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        [self addSubview:_titleLabel];
        
        self.showsTitle = NO;
    }
    return self;
}

- (void)setFrame:(CGRect)frame
{
    super.frame = frame;
    self.layer.cornerRadius = self.width/2;
}

- (void)setHighlighted:(BOOL)highlighted
{
    super.highlighted = highlighted;
    if (highlighted) {
        self.backgroundColor = [UIColor romoBlue];
    } else {
        self.backgroundColor = [UIColor romoWhite];
    }
}

- (void)setTitle:(NSString *)title {
    _title = title;
    
    _titleLabel.text = title;
    
    [self setImage:[UIImage imageNamed:[NSString stringWithFormat:@"R3UI-Controller-%@.png",title]] forState:UIControlStateNormal];
    [self setImage:[UIImage imageNamed:[NSString stringWithFormat:@"R3UI-Controller-%@Highlighted.png",title]] forState:UIControlStateHighlighted];
}

- (void)setActive:(BOOL)active
{
    if (self.canToggle) {
        _active = active;
        if (active) {
            self.alpha = 1.0;
        } else {
            self.alpha = 0.25;
        }
    }
}

- (void)setShowsTitle:(BOOL)showsTitle
{
    _showsTitle = showsTitle;
    _titleLabel.hidden = !showsTitle;
}

@end
