//
//  RMFaceColorIcon.m
//  Romo
//

#import "RMFaceColorActionIcon.h"
#import <QuartzCore/QuartzCore.h>
#import "UIView+Additions.h"

@interface RMFaceColorActionIcon ()

@property (nonatomic, strong) UIImageView *iPhone;

@property (nonatomic, strong) UIImageView *face;

@end

@implementation RMFaceColorActionIcon

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        _iPhone = [[UIImageView alloc] initWithImage:[UIImage smartImageNamed:@"iconFace.png"]];
        self.iPhone.centerX = self.contentView.width / 2;
        self.iPhone.bottom = self.contentView.height + 1;
        [self.contentView addSubview:self.iPhone];
        
        _face = [[UIImageView alloc] initWithFrame:CGRectMake(10, 21, 54, 81)];
        self.face.image = [UIImage imageNamed:@"romoFaceColor.png"];
        [self.iPhone addSubview:self.face];
    }
    return self;
}

@end
