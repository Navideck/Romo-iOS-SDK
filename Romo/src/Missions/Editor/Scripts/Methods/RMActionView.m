//
//  RMInstructionView.m
//  Romo
//

#import "RMActionView.h"
#import <QuartzCore/QuartzCore.h>
#import "UIView+Additions.h"
#import "UIFont+RMFont.h"
#import "UIButton+RMButtons.h"
#import "UIImage+Tint.h"
#import "RMAction.h"
#import "RMParameter.h"
#import "RMSoundEffect.h"
#import "RMDriveActionView.h"
#import "RMVideoActionView.h"
#import "RMPictureActionView.h"
#import "RMSayActionView.h"
#import "RMTurnActionView.h"
#import "RMWaitActionView.h"
#import "RMLightActionView.h"
#import "RMSongActionView.h"
#import "RMTiltActionView.h"
#import "RMFaceActionView.h"
#import "RMShuffleActionView.h"
#import "RMLookActionView.h"
#import "RMSquareActionView.h"
#import "RMNoActionView.h"
#import "RMFartActionView.h"
#import "RMDoodleActionView.h"
#import "RMAlarmActionView.h"
#import "RMExploreActionView.h"
#import "RMFaceColorActionView.h"

@interface RMActionView ()

@property (nonatomic, strong) UIImageView *background;
@property (nonatomic, strong) UIImageView *fullScreenBackground;

/** White centered text displaying the title property */
@property (nonatomic, strong) UILabel *titleLabel;

/** Dark centered text displaying the subtitle property */
@property (nonatomic, strong) UILabel *subtitleLabel;

/** A label showing the number property */
@property (nonatomic, strong) UILabel *numberLabel;

/** Shown when editing an action */
@property (nonatomic, strong) UIButton *deleteButton;
@property (nonatomic, strong) UIButton *dismissButton;

@property (nonatomic, strong) UITapGestureRecognizer *contentViewTapRecognizer;
@property (nonatomic, strong) UILongPressGestureRecognizer *contentViewLongPressRecognizer;
@property (nonatomic, strong) UISwipeGestureRecognizer *contentViewHorizontalSwipeRecognizer;

/** Whether the view is non-editing (collapsed bubble) and deletable */
@property (nonatomic) BOOL showsDeleteButton;

@property (nonatomic, strong) UIImageView *glow;

@end

@implementation RMActionView

//static const CGFloat minDeleteDistance = 50;

- (RMActionView *)initWithTitle:(NSString *)title
{
    title = [title lowercaseString];
    CGRect frame = CGRectMake(0, 0, [UIScreen mainScreen].bounds.size.width, actionViewHeight);

    if ([title isEqualToString:@"drive forward"]) {
        RMDriveActionView *driveView = [[RMDriveActionView alloc] initWithFrame:frame];
        driveView.forward = YES;
        return driveView;
    } else if ([title isEqualToString:@"drive backward"]) {
        RMDriveActionView *driveView = [[RMDriveActionView alloc] initWithFrame:frame];
        driveView.forward = NO;
        return driveView;
    } else if ([title isEqualToString:@"turn"]) {
        return [[RMTurnActionView alloc] initWithFrame:frame];
    } else if ([title isEqualToString:@"take a photo"]) {
        return [[RMPictureActionView alloc] initWithFrame:frame];
    } else if ([title isEqualToString:@"record a video"]) {
        RMVideoActionView *videoView = [[RMVideoActionView alloc] initWithFrame:frame];
        return videoView;
    } else if ([title isEqualToString:@"say"]) {
        return [[RMSayActionView alloc] initWithFrame:frame];
    } else if ([title isEqualToString:@"play $"]) {
        RMSongActionView *songView = [[RMSongActionView alloc] initWithFrame:frame];
        return songView;
    } else if ([title isEqualToString:@"act $"]) {
        RMFaceActionView *expressionView = [[RMFaceActionView alloc] initWithFrame:frame];
        expressionView.showingEmotion = NO;
        return expressionView;
    } else if ([title isEqualToString:@"become $"]) {
        RMFaceActionView *emoteView = [[RMFaceActionView alloc] initWithFrame:frame];
        emoteView.showingEmotion = YES;
        return emoteView;
    } else if ([title isEqualToString:@"tilt"]) {
        return [[RMTiltActionView alloc] initWithFrame:frame];
    } else if ([title isEqualToString:@"turn on romo's light"]) {
        RMLightActionView *lightView = [[RMLightActionView alloc] initWithFrame:frame];
        lightView.state = RMLightActionViewStateOn;
        return lightView;
    } else if ([title isEqualToString:@"turn off romo's light"]) {
        RMLightActionView *lightView = [[RMLightActionView alloc] initWithFrame:frame];
        lightView.state = RMLightActionViewStateOff;
        return lightView;
    } else if ([title isEqualToString:@"blink romo's light"]) {
        RMLightActionView *lightView = [[RMLightActionView alloc] initWithFrame:frame];
        lightView.state = RMLightActionViewStateBlink;
        return lightView;
    } else if ([title isEqualToString:@"pause"]) {
        return [[RMWaitActionView alloc] initWithFrame:frame];
    } else if ([title isEqualToString:@"shuffle music"]) {
        return [[RMShuffleActionView alloc] initWithFrame:frame];
    } else if ([title isEqualToString:@"look"]) {
        return [[RMLookActionView alloc] initWithFrame:frame];
    } else if ([title isEqualToString:@"drive in a square"]) {
        return [[RMSquareActionView alloc] initWithFrame:frame];
    } else if ([title isEqualToString:@"nod \"yes!\""]) {
        RMTiltActionView *tiltView = [[RMTiltActionView alloc] initWithFrame:frame];
        tiltView.noddingYes = YES;
        return tiltView;
    } else if ([title isEqualToString:@"shake \"no!\""]) {
        return [[RMNoActionView alloc] initWithFrame:frame];
    } else if ([title isEqualToString:@"backfire"]) {
        return [[RMFartActionView alloc] initWithFrame:frame];
    } else if ([title isEqualToString:@"doodle"]) {
        return [[RMDoodleActionView alloc] initWithFrame:frame];
    } else if ([title isEqualToString:@"sound the alarm"]) {
        return [[RMAlarmActionView alloc] initWithFrame:frame];
    } else if ([title isEqualToString:@"start hiccuping"]) {
        RMFaceActionView *expressionView = [[RMFaceActionView alloc] initWithFrame:frame];
        expressionView.showingEmotion = NO;
        RMParameter *hiccupParameter = [[RMParameter alloc] initWithType:RMParameterExpression];
        hiccupParameter.value = @(RMCharacterExpressionHiccup);
        expressionView.parameters = @[hiccupParameter];
        return expressionView;
    } else if ([title isEqualToString:@"start exploring"]) {
        RMExploreActionView *exploreView = [[RMExploreActionView alloc] initWithFrame:frame];
        exploreView.stopping = NO;
        return exploreView;
    } else if ([title isEqualToString:@"stop exploring"]) {
        RMExploreActionView *exploreView = [[RMExploreActionView alloc] initWithFrame:frame];
        exploreView.stopping = YES;
        return exploreView;
    } else if ([title isEqualToString:@"change my color"]) {
        RMFaceColorActionView *faceColorView = [[RMFaceColorActionView alloc] initWithFrame:frame];
        return faceColorView;
    }
    return nil;
}

- (id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {        
        _background = [[UIImageView alloc] initWithImage:[[UIImage imageNamed:@"actionViewBackground.png"] resizableImageWithCapInsets:UIEdgeInsetsMake(46, 46, 46, 46) resizingMode:UIImageResizingModeStretch]];
        self.background.left = 19;
        [self addSubview:self.background];
        
        _contentView = [[UIView alloc] initWithFrame:CGRectMake(22.5, 1.5, self.background.width - 7.0, self.height - 7.5)];
        self.contentView.layer.cornerRadius = 38.0;
        self.contentView.clipsToBounds = YES;
        [self.contentView addGestureRecognizer:self.contentViewTapRecognizer];
        [self.contentView addGestureRecognizer:self.contentViewLongPressRecognizer];
        [self.contentView addGestureRecognizer:self.contentViewHorizontalSwipeRecognizer];
        [self addSubview:self.contentView];
        
        [self.contentView insertSubview:self.numberLabel atIndex:0];

        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleApplicationWillEnterForegroundNotification:) name:UIApplicationWillEnterForegroundNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleApplicationDidEnterBackgroundNotification:) name:UIApplicationDidEnterBackgroundNotification object:nil];
    }
    return self;
}

#pragma mark - Public Properties

- (void)setTitle:(NSString *)title
{
    _title = title;
    
    if (!self.titleLabel) {
        self.titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(26, 6, self.contentView.width - 52, 30)];
        self.titleLabel.backgroundColor = [UIColor clearColor];
        self.titleLabel.textColor = [UIColor whiteColor];
        self.titleLabel.shadowColor = [UIColor colorWithWhite:0.0 alpha:0.4];
        self.titleLabel.shadowOffset = CGSizeMake(0, -1);
        self.titleLabel.font = [UIFont mediumFont];
        self.titleLabel.numberOfLines = 1;
        self.titleLabel.minimumScaleFactor = 0.5;
        self.titleLabel.adjustsFontSizeToFitWidth = YES;
        self.titleLabel.textAlignment = NSTextAlignmentCenter;
        [self.contentView insertSubview:self.titleLabel atIndex:0];
    }
    NSString *actionTitle;
    
    if (self.class != [RMFaceActionView class]
        && self.class != [RMTurnActionView class]) {
         actionTitle = [[NSBundle mainBundle] localizedStringForKey:[NSString stringWithFormat:@"Action-title-%@", title]
                                                                       value:nil
                                                                       table:@"MissionActions"];
    } else {
        actionTitle = title;
    }
    
    self.titleLabel.text = actionTitle;
}

- (void)setSubtitle:(NSString *)subtitle
{
    _subtitle = subtitle;
    
    if (!self.subtitleLabel) {
        self.subtitleLabel = [[UILabel alloc] initWithFrame:CGRectMake(26, 32, self.contentView.width - 52, 18)];
        self.subtitleLabel.backgroundColor = [UIColor clearColor];
        self.subtitleLabel.textColor = [UIColor colorWithHue:0.569 saturation:1.0 brightness:0.5 alpha:1.0];
        self.subtitleLabel.shadowColor = [UIColor colorWithWhite:1.0 alpha:0.4];
        self.subtitleLabel.shadowOffset = CGSizeMake(0, 1);
        self.subtitleLabel.font = [UIFont smallFont];
        self.subtitleLabel.textAlignment = NSTextAlignmentCenter;
        [self.contentView insertSubview:self.subtitleLabel atIndex:0];
    }
    // The subtitles that need localization will do it in their own implementation
    self.subtitleLabel.text = subtitle;
}

- (void)setNumber:(int)number
{
    if (number != _number) {
        _number = number;
        
        self.numberLabel.text = [NSString stringWithFormat:@"%d",number];
        self.numberLabel.size = [self.numberLabel.text sizeWithFont:self.numberLabel.font];
        self.numberLabel.centerY = self.contentView.height / 2.0;
        self.numberLabel.left = 10;
    }
}

- (UILabel *)numberLabel
{
    if (!_numberLabel) {
        _numberLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _numberLabel.font = [UIFont largeFont];
        _numberLabel.backgroundColor = [UIColor clearColor];
        _numberLabel.textColor = [UIColor colorWithHue:0.569 saturation:1.0 brightness:0.5 alpha:1.0];
        _numberLabel.shadowColor = [UIColor colorWithWhite:1.0 alpha:0.4];
        _numberLabel.shadowOffset = CGSizeMake(0, 2);
    }
    return _numberLabel;
}

- (void)setHighlighted:(BOOL)highlighted
{
    if (highlighted != _highlighted) {
        _highlighted = highlighted;
        self.alpha = highlighted ? 0.65 : 1.0;
    }
}

- (void)setGlowing:(BOOL)glowing
{
    if (glowing != _glowing) {
        _glowing = glowing;
        
        if (glowing) {
            self.glow.alpha = 0.25;
            [self addSubview:self.glow];
            [UIView animateWithDuration:0.65 delay:0.0 options:UIViewAnimationOptionAutoreverse | UIViewAnimationOptionRepeat | UIViewAnimationOptionBeginFromCurrentState
                             animations:^{
                                 self.glow.alpha = 1.0;
                             } completion:nil];
        } else {
            [UIView animateWithDuration:0.25 delay:0.0 options:UIViewAnimationOptionBeginFromCurrentState
                             animations:^{
                                 self.glow.alpha = 0.0;
                             } completion:^(BOOL finished) {
                                 [self.glow removeFromSuperview];
                             }];
        }
    }
}

#pragma mark -- Private Properties

- (UITapGestureRecognizer *)contentViewTapRecognizer
{
    if (!_contentViewTapRecognizer) {
        _contentViewTapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(didTap:)];
    }
    
    return _contentViewTapRecognizer;
}

- (UILongPressGestureRecognizer *)contentViewLongPressRecognizer
{
    if (!_contentViewLongPressRecognizer) {
        _contentViewLongPressRecognizer = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(didLongPress:)];
    }
    
    return _contentViewLongPressRecognizer;
}

- (UISwipeGestureRecognizer *)contentViewHorizontalSwipeRecognizer
{
    if (!_contentViewHorizontalSwipeRecognizer) {
        _contentViewHorizontalSwipeRecognizer = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(didHorizontalSwipe:)];
        [_contentViewHorizontalSwipeRecognizer setDirection:(UISwipeGestureRecognizerDirectionRight | UISwipeGestureRecognizerDirectionLeft)];
    }

    return _contentViewHorizontalSwipeRecognizer;
}

- (UIImageView *)glow
{
    if (!_glow) {
        _glow = [[UIImageView alloc] initWithImage:[[UIImage imageNamed:@"actionViewGlow.png"] resizableImageWithCapInsets:UIEdgeInsetsMake(75, 75, 75, 75)]];
        _glow.frame = CGRectMake(3.5, -17.5, self.width - 7, self.height + 30);
    }
    return _glow;
}

#pragma mark - Public Methods

- (void)willLayoutForEditing:(BOOL)editing
{
    if (editing) {
        self.titleLabel.font = [UIFont largeFont];
        self.titleLabel.transform = CGAffineTransformMakeScale(20.0 / 26.0, 20.0 / 26.0);

        self.dismissButton.alpha = 0.0;

        self.fullScreenBackground.frame = CGRectMake(self.background.left + 3, self.background.top, self.background.width - 8, self.background.height - 4);
        self.fullScreenBackground.alpha = 1.0;

        [self addSubview:self.dismissButton];
        [self insertSubview:self.fullScreenBackground belowSubview:self.background];
        [self.deleteButton removeFromSuperview];
        
    } else {
        self.background.alpha = 1.0;

        self.titleLabel.font = [UIFont mediumFont];
        self.titleLabel.transform = CGAffineTransformMakeScale(26.0 / 20.0, 26.0 / 20.0);

        [self insertSubview:self.background belowSubview:self.fullScreenBackground];
    }
}

- (void)setEditing:(BOOL)editing
{
    if (editing != _editing) {
        _editing = editing;

        if (editing) {
            self.background.frame = CGRectMake(0, 0, self.width, self.height + 10);
            self.contentView.frame = self.bounds;
            self.fullScreenBackground.frame = self.bounds;

            self.background.alpha = 0.0;
            self.dismissButton.alpha = 1.0;
            self.numberLabel.alpha = 0.0;

            self.titleLabel.transform = CGAffineTransformIdentity;
            self.titleLabel.center = CGPointMake(self.contentView.width / 2, 26.0);
            self.subtitleLabel.center = CGPointMake(self.contentView.width / 2, 50.0);

            [self.contentView removeAllGestureRecognizers];
        } else {
            self.background.frame = (CGRect){19, 0, self.background.image.size};
            self.contentView.frame = CGRectMake(22.0, 0.5, self.background.width - 5.5, actionViewHeight - 5.0);
            self.fullScreenBackground.frame = self.background.frame;
            
            self.fullScreenBackground.alpha = 0.0;
            self.dismissButton.alpha = 0.0;
            self.numberLabel.alpha = 1.0;

            self.titleLabel.transform = CGAffineTransformIdentity;
            self.titleLabel.center = CGPointMake(self.contentView.width / 2, 21.0);
            self.subtitleLabel.center = CGPointMake(self.contentView.width / 2, 41);
            
            [self.contentView addGestureRecognizer:self.contentViewTapRecognizer];
            [self.contentView addGestureRecognizer:self.contentViewLongPressRecognizer];
            [self.contentView addGestureRecognizer:self.contentViewHorizontalSwipeRecognizer];
        }
    }
}

- (void)didLayoutForEditing:(BOOL)editing
{
    if (editing) {
        [self.background removeFromSuperview];
    } else {
        [self.dismissButton removeFromSuperview];
        [self.fullScreenBackground removeFromSuperview];
    }
}

- (void)setShowsDeleteButton:(BOOL)showsDeleteButton
{
    if (showsDeleteButton != _showsDeleteButton && self.allowsDeletingActions) {
        _showsDeleteButton = showsDeleteButton;

        CGFloat left = self.contentView.left;
        CGFloat backgroundLeft = self.background.left;
        CGFloat glowLeft = _glow.left;
        [[UIApplication sharedApplication] beginIgnoringInteractionEvents];
        if (showsDeleteButton) {
            [RMSoundEffect playForegroundEffectWithName:deleteSwipeButtonSound repeats:NO gain:1.0];
            self.deleteButton.left = self.width;
            self.deleteButton.centerY = self.contentView.height / 2 - 1;
            self.deleteButton.alpha = 0.0;
            [self addSubview:self.deleteButton];
            
            [UIView animateWithDuration:0.35 delay:0 options:UIViewAnimationOptionBeginFromCurrentState
                             animations:^{
                                 self.contentView.transform = CGAffineTransformMakeScale(0.8, 1.0);
                                 self.contentView.left = left;
                                 
                                 self.background.transform = self.contentView.transform;
                                 self.background.left = backgroundLeft;
                                 
                                 self->_glow.transform = self.contentView.transform;
                                 self->_glow.left = glowLeft + 4.0;
                                 
                                 self.deleteButton.left = self.contentView.width + 8;
                                 self.deleteButton.alpha = 1.0;

                                 [[UIApplication sharedApplication] endIgnoringInteractionEvents];
                             } completion:nil];
        } else {
            [RMSoundEffect playForegroundEffectWithName:deleteUnswipeButtonSound repeats:NO gain:1.0];
            [UIView animateWithDuration:0.35 delay:0 options:UIViewAnimationOptionBeginFromCurrentState
                             animations:^{
                                 self.contentView.transform = CGAffineTransformIdentity;
                                 self.contentView.left = left;
                                 
                                 self.background.transform = self.contentView.transform;
                                 self.background.left = backgroundLeft;
                                 
                                 self->_glow.transform = self.contentView.transform;
                                 self->_glow.left = glowLeft - 4.0;
                                 
                                 self.deleteButton.left = self.width;
                                 self.deleteButton.alpha = 0.0;
                             } completion:^(BOOL finished) {
                                 [self.deleteButton removeFromSuperview];
                                 [[UIApplication sharedApplication] endIgnoringInteractionEvents];
                             }];
        }
    }
}

#pragma mark - animation

- (void)startAnimating
{
}

- (void)stopAnimating
{
}

- (void)removeFromSuperview
{
    [super removeFromSuperview];

    [self stopAnimating];
}

- (void)didMoveToSuperview
{
    [super didMoveToSuperview];
    
    if (self.superview) {
        [self startAnimating];
    }
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

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self stopAnimating];
}

#pragma mark - Private Methods

- (UIButton *)deleteButton
{
    if (!_deleteButton) {
        _deleteButton = [[UIButton alloc] initWithFrame:CGRectMake(self.width - 80, 0, 80, 60)];
        [_deleteButton setImage:[UIImage imageNamed:@"actionViewDeleteButton.png"] forState:UIControlStateNormal];
        [_deleteButton setImage:[[UIImage imageNamed:@"actionViewDeleteButton.png"] tintedImageWithColor:[UIColor colorWithWhite:1.0 alpha:0.65]] forState:UIControlStateHighlighted];
        _deleteButton.imageView.contentMode = UIViewContentModeCenter;
        _deleteButton.imageEdgeInsets = UIEdgeInsetsMake(0, 20, 0, 0);
        [_deleteButton addTarget:self action:@selector(handleDeleteButtonTouch:) forControlEvents:UIControlEventTouchUpInside];
    }
    return _deleteButton;
}

- (UIButton *)dismissButton
{
    if (!_dismissButton) {
        _dismissButton = [UIButton backButtonWithImage:nil];
        [_dismissButton addTarget:self action:@selector(handleDismissButtonTouch:) forControlEvents:UIControlEventTouchUpInside];
    }
    return _dismissButton;
}

- (UIImageView *)fullScreenBackground
{
    if (!_fullScreenBackground) {
        _fullScreenBackground = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"actionViewFullscreenBackground.png"]];
        _fullScreenBackground.layer.cornerRadius = 38.0;
        _fullScreenBackground.clipsToBounds = YES;
    }
    return _fullScreenBackground;
}

- (void)handleDeleteButtonTouch:(UIButton *)deleteButton
{
    [self.delegate actionViewDidDelete:self];
}

- (void)handleDismissButtonTouch:(UIButton *)confirmButton
{
    [self.delegate actionViewDidTouchConfirm:self];
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    if (self.isEditing) {
        CGPoint touchLocation = [[touches anyObject] locationInView:self];
        if (touchLocation.y < 80) {
            [self.delegate actionViewDidTouchConfirm:self];
        }
    } else {
        self.showsDeleteButton = NO;
    }
}

- (void)didTap:(UITapGestureRecognizer *)tap
{
    if (self.showsDeleteButton) {
        self.showsDeleteButton = NO;
    } else {
        if (!self.isEditing) {
            [self.delegate toggleEditingForActionView:self];
        }
    }
}

- (void)didLongPress:(UILongPressGestureRecognizer *)longPress
{
    static CGPoint initialLocation = (CGPoint){0,0};
    static CGPoint initialOrigin = (CGPoint){0,0};
    
    CGPoint currentLocation = [longPress locationInView:self.superview];
    CGPoint offset = CGPointMake(currentLocation.x - initialLocation.x, currentLocation.y - initialLocation.y);
    
    if (longPress.state == UIGestureRecognizerStateBegan) {
        initialLocation = currentLocation;
        initialOrigin = self.origin;
        [self.delegate actionView:self didDragByOffset:CGPointZero fromOrigin:initialOrigin];
        self.highlighted = YES;
        self.showsDeleteButton = NO;
    } else if (longPress.state == UIGestureRecognizerStateChanged) {
        [self.delegate actionView:self didDragByOffset:offset fromOrigin:initialOrigin];
    } else if (longPress.state == UIGestureRecognizerStateEnded || longPress.state == UIGestureRecognizerStateCancelled) {
        [self.delegate actionView:self didEndDragging:offset fromOrigin:initialOrigin];
    }
}

- (void)didHorizontalSwipe:(UISwipeGestureRecognizer *)horizontalSwipe
{
    self.showsDeleteButton = !self.showsDeleteButton;
}

@end
