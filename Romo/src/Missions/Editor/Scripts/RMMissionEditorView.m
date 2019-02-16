//
//  RMMissionEditorView.m
//  Romo
//

#import "RMMissionEditorView.h"
#import <QuartzCore/QuartzCore.h>
#import "UIView+Additions.h"
#import "UIFont+RMFont.h"
#import "UIImage+Tint.h"
#import "UIColor+RMColor.h"
#import <Romo/RMMath.h>
#import "RMMission.h"
#import "RMEventsView.h"
#import "RMActionView.h"
#import "RMAction.h"
#import "RMParameter.h"
#import "RMParameterInput.h"
#import "RMActionBrowserVC.h"
#import "RMGradientLabel.h"

static const CGFloat scrollMargin = 42.0;
static const CGFloat maxScrollSpeed = 16.0;
static const CGFloat scrollAcceleration = 0.5;

static const CGFloat navigationBarHeight = 62.0;
static const CGFloat briefingWindowTop = 16.0;
static const CGFloat addArrowOffset = 23.0;

@interface RMMissionEditorView ()

/** When reordering parameters, this is the frame that is empty in the list */
@property (nonatomic) CGRect gapFrame;

/** The actionView being reordered */
@property (nonatomic, strong) RMActionView *draggingActionView;

/** Is a action view being edited? */
@property (nonatomic, readonly, getter=isEditing) BOOL editing;

@property (nonatomic, readwrite, strong) UIImageView *briefingWindow;
@property (nonatomic, readwrite, strong) UIButton *solveButton;
@property (nonatomic, readwrite, strong) RMEventsView *eventsView;
@property (nonatomic, readwrite, strong) RMSlideToStart *slideToStart;

@property (nonatomic, strong) NSTimer *scrollTimer;
@property (nonatomic) CGFloat scrollSpeed;

/** Scrolls the view with speed, positive is down, negative up, zero stops scrolling */
- (void)scrollWithSpeed:(float)speed;

/** Call to reposition and resize UI elements when things change */
- (void)layoutDidChange;

@end

@implementation RMMissionEditorView

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.alwaysBounceVertical = YES;
        self.showsVerticalScrollIndicator = NO;

        self.actionViews = [NSMutableArray array];

        [self layoutDidChange];
    }
    return self;
}

#pragma mark - Public Properties

- (void)setScript:(NSArray *)script
{
    _script = script;
    
    [self.actionViews makeObjectsPerformSelector:@selector(removeFromSuperview)];
    [self.actionViews removeAllObjects];
    
    if (self.showsEvents) {
        [self addSubview:self.eventsView];
    }
    
    for (int i = 0; i < script.count; i++) {
        [self insertAction:script[i] atIndex:i];
    }
    
    [self layoutDidChange];
}

- (void)setActionViewDelegate:(id<RMActionViewDelegate>)actionViewDelegate
{
    _actionViewDelegate = actionViewDelegate;
    for (RMActionView *actionView in self.actionViews) {
        actionView.delegate = actionViewDelegate;
    }
}

- (void)setActionBrowserVC:(RMActionBrowserVC *)actionBrowserVC
{
    _actionBrowserVC = actionBrowserVC;
    [self layoutDidChange];
}

- (UIImageView *)briefingWindow
{
    if (!_briefingWindow && self.mission) {
        _briefingWindow = [[UIImageView alloc] initWithImage:[[UIImage imageNamed:@"debriefingWindow.png"] resizableImageWithCapInsets:UIEdgeInsetsMake(37, 0, 37, 0)]];
        _briefingWindow.frame = CGRectMake(0, 0, 291, 0);
        _briefingWindow.userInteractionEnabled = YES;
        _briefingWindow.clipsToBounds = YES;
        
        CGFloat actualFontSize;

        RMGradientLabel *titleLabel = [[RMGradientLabel alloc] initWithFrame:CGRectZero];
        titleLabel.backgroundColor = [UIColor clearColor];
        titleLabel.gradientColor = [UIColor greenColor];
        titleLabel.text = self.mission.title;
        titleLabel.textAlignment = NSTextAlignmentCenter;
        titleLabel.size = [titleLabel.text sizeWithFont:[UIFont fontWithSize:28.0]
                                       minFontSize:16.0
                                    actualFontSize:&actualFontSize
                                          forWidth:_briefingWindow.width - 60
                                     lineBreakMode:NSLineBreakByClipping];
        titleLabel.font = [UIFont fontWithSize:actualFontSize];
        titleLabel.top = 28;
        titleLabel.centerX = _briefingWindow.width / 2;
        [_briefingWindow addSubview:titleLabel];
        
        UILabel *briefingLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        briefingLabel.backgroundColor = [UIColor clearColor];
        briefingLabel.textColor = [UIColor whiteColor];
        briefingLabel.font = [UIFont fontWithSize:18.0];
        briefingLabel.textAlignment = NSTextAlignmentCenter;
        briefingLabel.numberOfLines = 0;
        briefingLabel.text = self.mission.briefing;
        briefingLabel.size = [briefingLabel.text sizeWithFont:briefingLabel.font constrainedToSize:CGSizeMake(_briefingWindow.width - 72, 192)];
        briefingLabel.centerX = _briefingWindow.width / 2;
        briefingLabel.top = titleLabel.bottom + 10;
        [_briefingWindow addSubview:briefingLabel];
        
        self.solveButton.centerX = _briefingWindow.width / 2.0 + 8.0;
        self.solveButton.top = briefingLabel.bottom + 16.0;
        [_briefingWindow addSubview:self.solveButton];
        
        _briefingWindow.height = self.solveButton.bottom + 10;
    }
    return _briefingWindow;
}

- (UIButton *)solveButton
{
    if (!_solveButton) {
        _solveButton = [[UIButton alloc] initWithFrame:CGRectMake(0, 0, self.briefingWindow.width, 64)];
        _solveButton.titleLabel.font = [UIFont fontWithSize:18.0];
        [_solveButton setTitle:NSLocalizedString(@"SolveMission-Button-Title", @"SOLVE MISSION") forState:UIControlStateNormal];
        
        UIColor *color = [UIColor colorWithPatternImage:[RMGradientLabel gradientImageForColor:[UIColor greenColor] label:_solveButton.titleLabel]];
        [_solveButton setTitleColor:color forState:UIControlStateNormal];
        [_solveButton setTitleColor:[UIColor whiteColor] forState:UIControlStateHighlighted];
        
        [_solveButton setImage:[UIImage imageNamed:@"debriefingContinueChevronGreen.png"] forState:UIControlStateNormal];
        [_solveButton setImage:[[UIImage imageNamed:@"debriefingContinueChevronGreen.png"] tintedImageWithColor:[UIColor colorWithWhite:1.0 alpha:0.65]] forState:UIControlStateHighlighted];
        
        _solveButton.titleEdgeInsets = UIEdgeInsetsMake(0, 0, 0, 38);
        _solveButton.imageEdgeInsets = UIEdgeInsetsMake(0, _solveButton.width - 50, 0, 0);
        
        UIImageView *bar = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"debriefingWindowBar.png"]];
        bar.centerX = _solveButton.width / 2 - 8.0;
        [_solveButton insertSubview:bar atIndex:0];
    }
    return _solveButton;
}

- (RMEventsView *)eventsView
{
    if (!_eventsView) {
        _eventsView = [[RMEventsView alloc] initWithEvents:self.mission.events];
    }
    return _eventsView;
}

- (RMSlideToStart *)slideToStart
{
    if (!_slideToStart) {
        _slideToStart = [[RMSlideToStart alloc] initWithFrame:CGRectMake(16, 0, self.width - 32, 80)];
    }
    return _slideToStart;
}

- (UIButton *)addActionButton
{
    if (!_addActionButton) {
        _addActionButton = [[UIButton alloc] initWithFrame:CGRectMake(0, 0, 275, 83)];
        _addActionButton.centerX = self.width / 2;
        [_addActionButton setBackgroundImage:[[UIImage imageNamed:@"scriptPlusButton.png"] resizableImageWithCapInsets:UIEdgeInsetsMake(0, 45, 0, 45)] forState:UIControlStateNormal];
        [_addActionButton setBackgroundImage:[[UIImage imageNamed:@"scriptPlusButtonHighlighted.png"] resizableImageWithCapInsets:UIEdgeInsetsMake(0, 45, 0, 45)] forState:UIControlStateHighlighted];
        [_addActionButton setImage:[UIImage imageNamed:@"scriptPlusIcon.png"] forState:UIControlStateNormal];
        [_addActionButton setImage:[UIImage imageNamed:@"scriptPlusIconHighlighted.png"] forState:UIControlStateHighlighted];
        _addActionButton.imageEdgeInsets = UIEdgeInsetsMake(30, 0, -16, 0);
    }
    return _addActionButton;
}

- (UIView *)addActionArrow
{
    if (!_addActionArrow) {
        _addActionArrow = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.width, 64.0)];
        
        UIImageView *arrow = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"scriptPlusArrow.png"]];
        arrow.centerX = _addActionArrow.width / 2;
        [_addActionArrow addSubview:arrow];
        
        UIImageView *leftStripe = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"scriptPlusStripe.png"]];
        leftStripe.frame = CGRectMake(0, 20, arrow.left, 29.0);
        [_addActionArrow addSubview:leftStripe];
        
        UIImageView *rightStripe = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"scriptPlusStripe.png"]];
        rightStripe.frame = CGRectMake(arrow.right, 20, arrow.left, 29.0);
        [_addActionArrow addSubview:rightStripe];
        
        UIImageView *plusIcon = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"scriptPlusIcon.png"]];
        plusIcon.center = CGPointMake(_addActionArrow.width / 2, 32);
        [_addActionArrow addSubview:plusIcon];
    }
    return _addActionArrow;
}

- (UIButton *)repeatButton
{
    if (!_repeatButton) {
        _repeatButton = [[UIButton alloc] initWithFrame:CGRectMake(0, 0, 132, 83)];
        [_repeatButton setBackgroundImage:[[UIImage imageNamed:@"scriptPlusButton.png"] resizableImageWithCapInsets:UIEdgeInsetsMake(0, 45, 0, 45)] forState:UIControlStateNormal];
        [_repeatButton setBackgroundImage:[[UIImage imageNamed:@"scriptPlusButtonHighlighted.png"] resizableImageWithCapInsets:UIEdgeInsetsMake(0, 45, 0, 45)] forState:UIControlStateHighlighted];
        [_repeatButton setTitleColor:[UIColor blueTextColor] forState:UIControlStateNormal];
        _repeatButton.titleLabel.font = [UIFont mediumFont];
        _repeatButton.titleLabel.textAlignment = NSTextAlignmentCenter;
        _repeatButton.imageEdgeInsets = UIEdgeInsetsMake(36, 29, -12, 0);
    }
    return _repeatButton;
}

#pragma mark - Public Methods

- (RMActionView *)addAction:(RMAction *)action
{
    return [self insertAction:action atIndex:self.actionViews.count];
}

- (RMActionView *)insertAction:(RMAction *)action atIndex:(NSInteger)index
{
    if (action) {
        RMActionView *actionView = [[RMActionView alloc] initWithTitle:action.title];
        actionView.title = action.title;
        actionView.delegate = self.actionViewDelegate;
        actionView.parameters = action.parameters;
        actionView.locked = action.isLocked;
        actionView.allowsDeletingActions = self.mission.allowsDeletingActions && action.isDeletable;
        [self.actionViews insertObject:actionView atIndex:index];
        [self addSubview:actionView];

        return actionView;
    }
    return nil;
}

#pragma mark - ActionView Delegate

- (void)actionView:(RMActionView *)actionView didDragByOffset:(CGPoint)offset fromOrigin:(CGPoint)origin
{
    _draggingActionView = actionView;

    if (CGRectIsEmpty(self.gapFrame)) {
        self.gapFrame = (CGRect){origin, actionView.size};
    }
    
    actionView.origin = CGPointMake(origin.x, origin.y + offset.y);
    [self reorderActionViews];
    
    CGFloat y = self.contentOffset.y;
    CGFloat h = self.height;
    CGFloat contentHeight = self.contentSize.height;
    
    BOOL atBottomOfScreen = (actionView.bottom > y + h - scrollMargin);
    BOOL canScrollDown = y < contentHeight - h;
    BOOL atTopOfScreen = (actionView.top < y + scrollMargin);
    BOOL canScrollUp = y > 0;
    
    if (((atBottomOfScreen && canScrollDown) || (atTopOfScreen && canScrollUp))) {
        // If we're not already scrolling in that direction, then start
        if (!((self.scrollSpeed < 0 && atTopOfScreen) || (self.scrollSpeed > 0 && atBottomOfScreen))) {
            CGFloat speed = atTopOfScreen ? -1.0 : 1.0;
            [self scrollWithSpeed:speed];
        }
    } else {
        [self scrollWithSpeed:0];
    }
}

- (int)actionView:(RMActionView *)actionView didEndDragging:(CGPoint)offset fromOrigin:(CGPoint)origin
{
    [self scrollWithSpeed:0];
    
    actionView.highlighted = NO;
    
    // Insert the moved view into the appropriate index in the script
    int index = 0;
    for (RMActionView *otherActionView in self.actionViews) {
        if (otherActionView != actionView && otherActionView.bottom < self.gapFrame.origin.y) {
            index++;
        }
    }
    [self.actionViews removeObject:actionView];
    [self.actionViews insertObject:actionView atIndex:index];
    
    self.draggingActionView = nil;
    self.gapFrame = CGRectZero;
    
    [UIView animateWithDuration:0.2
                     animations:^{
                         [self layoutDidChange];
                     }];
    
    return index;
}

#pragma mark - Private Methods

- (void)scrollWithSpeed:(float)speed
{
    [self.scrollTimer invalidate];
    if (speed != 0) {
        self.scrollSpeed = speed;
        self.scrollTimer = [NSTimer scheduledTimerWithTimeInterval:1.0/30.0 target:self selector:@selector(scroll:) userInfo:nil repeats:YES];
    } else {
        self.scrollSpeed = 0.0;
        self.scrollTimer = nil;
    }
}

- (void)scroll:(NSTimer *)timer
{
    CGFloat jump = CLAMP(-self.contentOffset.y, self.scrollSpeed, self.contentSize.height - self.height - self.contentOffset.y);
    CGFloat destination = self.contentOffset.y + jump;
    
    self.contentOffset = CGPointMake(self.contentOffset.x, destination);
    self.draggingActionView.top += jump;
    [self reorderActionViews];
    
    float sign = self.scrollSpeed < 0 ? -1 : 1;
    self.scrollSpeed = CLAMP(-maxScrollSpeed, self.scrollSpeed + (sign * scrollAcceleration), maxScrollSpeed);
}

- (void)reorderActionViews
{
    [self bringSubviewToFront:self.draggingActionView];
    [UIView animateWithDuration:0.20
                     animations:^{
                         // For every other action view, see if we've dragged above or below them, shifting
                         // them appropriately
                         for (RMActionView *otherView in self.actionViews) {
                             if (otherView != self.draggingActionView) {
                                 // If we dragged above them and the gap is below them, move them down (or vice-versa)
                                 BOOL draggedAboveOtherView = (self.draggingActionView.top < otherView.centerY);
                                 BOOL draggedBelowOtherView = (self.draggingActionView.bottom > otherView.centerY);
                                 BOOL gapAboveOtherView = (self.gapFrame.origin.y + self.gapFrame.size.height) < otherView.top;
                                 if ((draggedAboveOtherView && !gapAboveOtherView) ||
                                     (draggedBelowOtherView && gapAboveOtherView)) {
                                     self.gapFrame = otherView.frame;
                                     float direction = (draggedAboveOtherView && !gapAboveOtherView) ? 1 : -1;
                                     otherView.top += direction * actionViewYGap;
                                     otherView.number += direction;
                                     self.draggingActionView.number -= direction;
                                 }
                             }
                         }
                     }];
}

- (BOOL)isEditing
{
    for (RMActionView *actionView in self.actionViews) {
        if (actionView.isEditing) {
            return YES;
        }
    }
    return NO;
}

- (void)layoutDidChange
{
    _briefingWindow.top = navigationBarHeight + briefingWindowTop;
    CGFloat scriptTop = _briefingWindow.bottom;
    
    if (self.showsEvents) {
        self.eventsView.top = _briefingWindow.bottom + topYGap;
        scriptTop = self.eventsView.bottom + topYGap;
    }

    if (!self.isEditing) {
        for (int i = 0; i < self.actionViews.count; i++) {
            RMActionView *actionView = self.actionViews[i];
            actionView.centerY = scriptTop + topYGap + (actionViewHeight / 2.0) + (i * actionViewYGap);
            actionView.number = i+1;
        }
    }
    
    BOOL showsAddButton = self.addActionButton.superview || self.addActionArrow.superview;
    BOOL showsSlideToStart = (self.slideToStart.superview != nil);
    
    CGFloat bottomOfLastAction = scriptTop + topYGap + (self.actionViews.count * actionViewYGap);
    CGFloat addButtonPadding = (showsAddButton ? self.addActionButton.height + self.actionBrowserVC.view.height : 0) + 2 * slideToStartPadding;
    CGFloat slidePadding = showsSlideToStart ? self.slideToStart.height + 2 * slideToStartPadding : 0;
    CGFloat bottomOfScrollView = bottomOfLastAction + addButtonPadding + slidePadding;
    
    if (_repeatButton.superview) {
        self.repeatButton.center = CGPointMake(self.width / 2.0 + 72, bottomOfLastAction + self.repeatButton.height / 2.0);
        self.addActionButton.width = self.repeatButton.width;
        self.addActionButton.center = CGPointMake(self.width / 2.0 - 74, bottomOfLastAction + self.addActionButton.height / 2.0);
    } else {
        self.addActionButton.width = 275.0;
        self.addActionButton.center = CGPointMake(self.width / 2.0, bottomOfLastAction + self.addActionButton.height / 2.0);
    }
    self.addActionArrow.center = CGPointMake(self.width / 2.0, self.addActionButton.centerY + addArrowOffset);
    
    self.slideToStart.bottom = MAX(self.height, bottomOfScrollView) - slideToStartPadding;
    
    if (!self.isEditing) {
        self.contentSize = CGSizeMake(self.width, MAX(self.height, bottomOfScrollView));
    }
}

@end
