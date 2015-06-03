//
//  RMRomoteDriveDriveButton.m
//  Romo
//

#import "RMRomoteDriveDriveButton.h"
#import "UIFont+RMFont.h"
#import "UIView+Additions.h"

@implementation RMRomoteDriveDriveButton

+ (id)buttonWithTitle:(NSString *)title
{
    RMRomoteDriveButton *button = [[RMRomoteDriveDriveButton alloc] initWithFrame:CGRectMake(0, 0, 60, 60)];
    button.title = title;
    return button;
}

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.title = @"Drive";
        self.showsTitle = YES;
        
        _titleLabel.top = 62;
        _titleLabel.font = [UIFont romoBoldFontWithSize:[UIFont romoMediumFontSize]];
        _titleLabel.shadowColor = [UIColor colorWithWhite:1.0 alpha:0.25];
        _titleLabel.shadowOffset = CGSizeMake(0, 1);
    }
    return self;
}

@end
