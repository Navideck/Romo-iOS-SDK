//
//  RMAlarmActionView.m
//  Romo
//

#import "RMAlarmActionView.h"
#import "UIView+Additions.h"

@interface RMAlarmActionView ()
@property (nonatomic, strong) UIImageView *alarm;

@end

@implementation RMAlarmActionView

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        _alarm = [[UIImageView alloc] initWithImage:[UIImage smartImageNamed:@"alarm.png"]];
        self.alarm.top = 0;
        self.alarm.centerX = self.contentView.width / 2.0;
        [self.contentView insertSubview:self.alarm atIndex:0];
    }
    return self;
}

- (void)setTitle:(NSString *)title
{
    super.title = title;
    [self.contentView insertSubview:self.alarm atIndex:0];
}

@end
