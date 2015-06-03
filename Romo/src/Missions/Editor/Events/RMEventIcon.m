//
//  RMEventIcon.m
//  Romo
//

#import "RMEventIcon.h"
#import "UIView+Additions.h"
#import "UIFont+RMFont.h"
#import "RMEvent.h"
#import "RMParameter.h"
#import "RMFavoriteColorRobotController.h"
#import "RMRomoMemory.h"

static const CGFloat size = 77;
static const CGFloat backgroundTopOffset = -12;

//static const CGFloat leftExpansionOffset = 14.0;
//static const CGFloat rightExpansionOffset = 74.0;

static const CGFloat showsTitleScale = 0.667;

@interface RMEventIcon ()

/** The green icon background */
@property (nonatomic, strong) UIImageView *background;
@property (nonatomic, strong) UILabel *titleLabel;

@end

@implementation RMEventIcon

- (id)initWithEvent:(RMEvent *)event
{
    self = [super initWithFrame:CGRectMake(0, 0, size, size)];
    if (self) {
        _event = event;
        
        self.background.frame = CGRectMake(0, backgroundTopOffset, self.width, self.height);
        [self addSubview:self.background];
        
        // A small graphic showing off this event
        UIImage *iconImage = [UIImage imageNamed:[NSString stringWithFormat:@"eventIcon%d_%@.png", event.type, event.parameter.value]];
        if (!iconImage) {
            iconImage = [UIImage imageNamed:[NSString stringWithFormat:@"eventIcon%d.png", event.type]];
        }
        
        if (self.event.type == RMEventFavoriteColor) {
            // For Favorite Color, the image is of Romo's face with a transparent background
            // Let's fill that with Romo's favorite color by dropping a colored view behind it
            NSString *favoriteHueString = [[RMRomoMemory sharedInstance] knowledgeForKey:favoriteColorKnowledgeKey];
            float favoriteHue = favoriteHueString.floatValue;
            UIColor *favoriteColor = [UIColor colorWithHue:favoriteHue saturation:1.0 brightness:1.0 alpha:1.0];

            UIView *favoriteColorView = [[UIView alloc] initWithFrame:CGRectMake(15, 2, 48, 66)];
            favoriteColorView.backgroundColor = favoriteColor;
            favoriteColorView.layer.cornerRadius = 2.0;
            [self.background addSubview:favoriteColorView];
        }
        
        UIImageView *icon = [[UIImageView alloc] initWithImage:iconImage];
        icon.layer.cornerRadius = icon.width / 2.0;
        [self.background addSubview:icon];
    }
    return self;
}

- (void)setShowsTitle:(BOOL)showsTitle
{
    _showsTitle = showsTitle;
    
    if (showsTitle) {
        self.transform = CGAffineTransformMakeScale(showsTitleScale, showsTitleScale);
        self.background.top = 0;
        self.title = self.event.parameterlessName;
        [self addSubview:self.titleLabel];
    } else {
        self.transform = CGAffineTransformIdentity;
        self.background.top = backgroundTopOffset;
        [self.titleLabel removeFromSuperview];
    }
}

- (void)setTitle:(NSString *)title
{
    _title = title;
    self.titleLabel.text = title;
    
    // size & center the label
    self.titleLabel.size = CGSizeMake(size + 20, size/2);
    self.titleLabel.textAlignment = NSTextAlignmentCenter;
    self.titleLabel.minimumScaleFactor = 0.5;
    self.titleLabel.numberOfLines = 1;
    self.titleLabel.adjustsFontSizeToFitWidth = YES;
    self.titleLabel.center = CGPointMake(self.background.width / 2.0, self.background.bottom + 8.0);
}

#pragma mark - Private Methods

- (UIImageView *)background
{
    if (!_background) {
        _background = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"eventIcon.png"]];
        _background.contentMode = UIViewContentModeScaleAspectFit;
    }
    return _background;
}

- (UILabel *)titleLabel
{
    if (!_titleLabel) {
        _titleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _titleLabel.backgroundColor = [UIColor clearColor];
        _titleLabel.textColor = [UIColor whiteColor];
        _titleLabel.font = [UIFont mediumFont];
    }
    return _titleLabel;
}

@end
