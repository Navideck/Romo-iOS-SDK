//
//  RMButtonIcon.m
//  Romo
//

#import "RMButtonIcon.h"
#import <QuartzCore/QuartzCore.h>
#import "UIView+Additions.h"
#import "UIFont+RMFont.h"

@interface RMButtonIcon ()

@property (nonatomic, strong) UILabel *titleLabel;

@end

@implementation RMButtonIcon

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.image = [UIImage imageNamed:@"iconBackground.png"];
        self.contentMode = UIViewContentModeTop;
        self.userInteractionEnabled = YES;

        _contentView = [[UIView alloc] initWithFrame:CGRectMake(8.5, 2.5, 84.5, 84.5)];
        self.contentView.layer.cornerRadius = 21.5;
        self.contentView.clipsToBounds = YES;
        [self addSubview:self.contentView];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleApplicationWillEnterForegroundNotification:) name:UIApplicationWillEnterForegroundNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleApplicationDidEnterBackgroundNotification:) name:UIApplicationDidEnterBackgroundNotification object:nil];
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)setTitle:(NSString *)title
{
    _title = title;
    if (!self.titleLabel) {
        self.titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 90, self.width, 36)];
        self.titleLabel.backgroundColor = [UIColor clearColor];
        self.titleLabel.textColor = [UIColor whiteColor];
        self.titleLabel.shadowColor = [UIColor colorWithWhite:0.0 alpha:0.4];
        self.titleLabel.shadowOffset = CGSizeMake(0, -1);
        self.titleLabel.font = [UIFont smallFont];
        self.titleLabel.textAlignment = NSTextAlignmentCenter;
        self.titleLabel.numberOfLines = 2;
        [self addSubview:self.titleLabel];
    }
    self.titleLabel.text = title;
    self.titleLabel.size = [self.titleLabel.text sizeWithFont:self.titleLabel.font constrainedToSize:CGSizeMake(self.width, 36) lineBreakMode:self.titleLabel.lineBreakMode];
    self.titleLabel.centerX = self.width / 2;
}

- (void)layoutForExpansion
{
    self.titleLabel.alpha = 0.0;
    self.titleLabel.transform = CGAffineTransformMakeScale(0.08, 0.4);
    self.titleLabel.top -= 32;
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    self.alpha = 0.88;
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
    CGPoint touchLocation = [[touches anyObject] locationInView:self];

    if (CGRectContainsPoint(self.bounds, touchLocation)) {
        self.alpha = 0.88;
    } else {
        self.alpha = 1.0;
    }
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    self.alpha = 1.0;
    CGPoint touchLocation = [[touches anyObject] locationInView:self];

    if (CGRectContainsPoint(self.bounds, touchLocation)) {
        [self.delegate didTouchButtonIcon:self];
    }
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
    self.alpha = 1.0;
}

- (void)handleApplicationWillEnterForegroundNotification:(NSNotification *)notification
{
    if (self.superview) {
        [self startAnimating];
    }
}

- (void)handleApplicationDidEnterBackgroundNotification:(NSNotification *)notification
{
    [self stopAnimating];
}

@end
