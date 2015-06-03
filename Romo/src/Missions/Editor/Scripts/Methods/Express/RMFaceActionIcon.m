//
//  RMExpressActionIcon
//  Romo
//

#import "RMFaceActionIcon.h"
#import <QuartzCore/QuartzCore.h>
#import "UIView+Additions.h"

@interface RMFaceActionIcon ()

@property (nonatomic, strong) UIImageView *iPhone;

@property (nonatomic, strong) UIImageView *face;

@end

@implementation RMFaceActionIcon

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        _iPhone = [[UIImageView alloc] initWithImage:[UIImage smartImageNamed:@"iconFace.png"]];
        self.iPhone.centerX = self.contentView.width / 2;
        self.iPhone.bottom = self.contentView.height + 1;
        [self.contentView addSubview:self.iPhone];

        _face = [[UIImageView alloc] initWithFrame:CGRectMake(10, 21, 54, 81)];
        [self.iPhone addSubview:self.face];
    }
    return self;
}

- (void)setEmotion:(RMCharacterEmotion)emotion
{
    _emotion = emotion;
    self.face.image = [UIImage imageNamed:[NSString stringWithFormat:@"romoEmotion%d@1x.png", emotion]];
}

- (void)setExpression:(RMCharacterExpression)expression
{
    _expression = expression;
    self.face.image = [UIImage imageNamed:[NSString stringWithFormat:@"romoExpression%d@1x.png", expression]];
}

@end
