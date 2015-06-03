//
//  RMSayActionIcon.m
//  Romo
//

#import "RMSayActionIcon.h"
#import <QuartzCore/QuartzCore.h>
#import "UIView+Additions.h"
#import "UIFont+RMFont.h"

@interface RMSayActionIcon ()

@end

@implementation RMSayActionIcon

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        UILabel *textLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 4, self.contentView.width, self.contentView.height)];
        textLabel.backgroundColor = [UIColor clearColor];
        textLabel.textColor = [UIColor whiteColor];
        textLabel.layer.shadowOpacity = 0.4;
        textLabel.layer.shadowRadius = 3.0;
        textLabel.layer.shadowColor = [UIColor blackColor].CGColor;
        textLabel.layer.shadowOffset = CGSizeMake(0, 2);
        textLabel.layer.shouldRasterize = YES;
        textLabel.layer.rasterizationScale = 2.0;
        textLabel.textAlignment = NSTextAlignmentCenter;
        textLabel.font = [UIFont fontWithSize:44];
        textLabel.text = NSLocalizedString(@"Say-Action-Default-Title", @"“Hi!”");
        [self.contentView addSubview:textLabel];
    }
    return self;
}

@end
