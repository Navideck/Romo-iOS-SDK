//
//  RMEventBrowserView.m
//  Romo
//

#import "RMEventBrowserView.h"
#import "UIView+Additions.h"
#import "UIFont+RMFont.h"
#import "UIButton+SoundEffects.h"
#import "UIImage+Tint.h"
#import "RMGradientLabel.h"
#import "RMEventIcon.h"
#import "RMSoundEffect.h"

static const CGFloat topPadding = 4;
static const int numberOfColumns = 3;
static const CGFloat padding = 88;

@interface RMEventBrowserView ()

/** Readwrite */
@property (nonatomic, strong, readwrite) UIImageView *borderWindow;
@property (nonatomic, strong, readwrite) UILabel *titleLabel;
@property (nonatomic, strong, readwrite) UIButton *dismissButton;
@property (nonatomic, strong, readwrite) UIScrollView *scrollView;

@end

@implementation RMEventBrowserView

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [self.borderWindow addSubview:self.titleLabel];
        [self addSubview:self.borderWindow];
    }
    return self;
}

- (UIImageView *)borderWindow
{
    if (!_borderWindow) {
        _borderWindow = [[UIImageView alloc] initWithImage:[[UIImage imageNamed:@"debriefingWindow.png"] resizableImageWithCapInsets:UIEdgeInsetsMake(37, 0, 37, 0)]];
        _borderWindow.frame = CGRectMake(0, 0, 291, self.height - 64);
        _borderWindow.center = CGPointMake(self.width / 2.0, self.height / 2.0 + 32.0);
        _borderWindow.userInteractionEnabled = YES;
        
        UIImageView *bar = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"debriefingWindowBar.png"]];
        bar.centerX = _borderWindow.width / 2;
        bar.bottom = _borderWindow.height - 10;
        [_borderWindow addSubview:bar];
        
        self.dismissButton.bottom = bar.bottom;
        self.dismissButton.centerX = _borderWindow.width / 2.0 + 8;
        [_borderWindow addSubview:self.dismissButton];
        
        self.scrollView.frame = CGRectMake(10, 70, _borderWindow.width - 20, _borderWindow.height - 144);
        [_borderWindow addSubview:self.scrollView];
    }
    return _borderWindow;
}

- (UILabel *)titleLabel
{
    if (!_titleLabel) {
        _titleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _titleLabel.backgroundColor = [UIColor clearColor];
        _titleLabel.textColor = [UIColor whiteColor];
        _titleLabel.font = [UIFont fontWithSize:32.0];
        _titleLabel.minimumScaleFactor = 0.5;
        _titleLabel.adjustsFontSizeToFitWidth = YES;
        _titleLabel.adjustsLetterSpacingToFitWidth = YES;
        _titleLabel.text = NSLocalizedString(@"EventBrowser-View-Title", @"Add an Event");
        _titleLabel.numberOfLines = 2;
        _titleLabel.textAlignment = NSTextAlignmentCenter;
        _titleLabel.size = [_titleLabel.text sizeWithFont:_titleLabel.font constrainedToSize:CGSizeMake(_borderWindow.width - 10, 44)];
        _titleLabel.top = 28;
        _titleLabel.centerX = _borderWindow.width / 2;
    }
    return _titleLabel;
}

- (UIButton *)dismissButton
{
    if (!_dismissButton) {
        _dismissButton = [[UIButton alloc] initWithFrame:CGRectMake(0, 0, self.borderWindow.width / 2.0, 64)];
        [_dismissButton setSoundEffect:[RMSoundEffect effectWithName:generalButtonSound] forControlEvents:UIControlEventTouchUpInside];
        _dismissButton.titleLabel.font = [UIFont fontWithSize:18.0];
        [_dismissButton setTitle:NSLocalizedString(@"EventBrowser-DismissButton-Title", @"DONE") forState:UIControlStateNormal];
        [_dismissButton setTitleColor:[UIColor colorWithPatternImage:[RMGradientLabel gradientImageForColor:[UIColor greenColor] label:_dismissButton.titleLabel]]
                             forState:UIControlStateNormal];
        [_dismissButton setImage:[UIImage imageNamed:@"debriefingContinueChevronGreen.png"] forState:UIControlStateNormal];
        [_dismissButton setImage:[[UIImage imageNamed:@"debriefingContinueChevronGreen.png"] tintedImageWithColor:[UIColor colorWithWhite:1.0 alpha:0.65]] forState:UIControlStateHighlighted];
        _dismissButton.titleEdgeInsets = UIEdgeInsetsMake(0, 0, 0, 38);
        _dismissButton.imageEdgeInsets = UIEdgeInsetsMake(0, _dismissButton.width - 44, 0, 0);
    }
    return _dismissButton;
}

- (void)setEventIcons:(NSArray *)eventIcons
{
    _eventIcons = eventIcons;
    
    __block float bottom = 0;
    [eventIcons enumerateObjectsUsingBlock:^(RMEventIcon *eventIcon, NSUInteger index, BOOL *stop) {
        // align the icons into n columns, decided by index % n
        CGFloat columnOffset = padding * (float)(((int)index % numberOfColumns) - 1);
        eventIcon.centerX = (self.borderWindow.width / 2.0) + columnOffset - 10.0;
        eventIcon.top = topPadding + padding * (index / numberOfColumns);
        [self.scrollView addSubview:eventIcon];
        
        // Compute how tall the scroll view should be
        if (eventIcon.bottom > bottom) {
            bottom = eventIcon.bottom;
        }
    }];
    
    self.scrollView.contentSize = CGSizeMake(self.scrollView.width, bottom + padding);
}

- (void)layoutForEventIconOptions:(NSArray *)eventIconOptions
{
    // animate all old icons out, new ones in
    [UIView animateWithDuration:0.15 delay:0.0 options:UIViewAnimationOptionCurveEaseIn
                     animations:^{
                         [self.eventIcons enumerateObjectsUsingBlock:^(RMEventIcon *eventIcon, NSUInteger index, BOOL *stop) {
                             eventIcon.left -= self.borderWindow.left;
                             eventIcon.alpha = 0.0;
                         }];
                     } completion:^(BOOL finished) {
                         [self.eventIcons enumerateObjectsUsingBlock:^(RMEventIcon *eventIcon, NSUInteger index, BOOL *stop) {
                             [eventIcon removeFromSuperview];
                         }];
                         self.eventIcons = eventIconOptions;
                     }];
}

#pragma mark - Private Properties

- (UIScrollView *)scrollView
{
    if (!_scrollView) {
        _scrollView = [[UIScrollView alloc] initWithFrame:CGRectZero];
        _scrollView.showsVerticalScrollIndicator = NO;
        _scrollView.bounces = YES;
    }
    return _scrollView;
}

@end
