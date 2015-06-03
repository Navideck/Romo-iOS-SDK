//
//  RMRomoteDriveBackButton.m
//

#import "RMRomoteDriveSettingsButton.h"
#import "UIView+Additions.h"
#import "UIColor+RMColor.h"
#import "UIFont+RMFont.h"

@implementation RMRomoteDriveSettingsButton

+ (id)settingsButton
{
    return [[RMRomoteDriveSettingsButton alloc] initWithFrame:CGRectMake(0, 0, 44, 44)];
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
        
        [self setImage:[UIImage imageNamed:@"R3UI-Controller-Controllers.png"] forState:UIControlStateNormal];
        [self setImage:[UIImage imageNamed:@"R3UI-Controller-ControllersHighlighted.png"] forState:UIControlStateHighlighted];
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

@end
