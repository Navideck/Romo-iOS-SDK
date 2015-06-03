//
//  RMShuffleActionIcon.m
//  Romo
//

#import "RMShuffleActionIcon.h"
#import <QuartzCore/QuartzCore.h>
#import "UIView+Additions.h"

@interface RMShuffleActionIcon ()

@end

@implementation RMShuffleActionIcon

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        UIImageView *shuffle = [[UIImageView alloc] initWithImage:[UIImage smartImageNamed:@"shuffleIcon.png"]];
        shuffle.frame = CGRectMake(20, 20, self.contentView.width - 40, self.contentView.height - 40);
        shuffle.contentMode = UIViewContentModeScaleAspectFit;
        [self.contentView addSubview:shuffle];
    }
    return self;
}

@end
