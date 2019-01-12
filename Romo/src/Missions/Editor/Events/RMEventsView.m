//
//  RMEventsView.m
//  Romo
//

#import "RMEventsView.h"
#import "UIView+Additions.h"
#import "UIFont+RMFont.h"
#import "RMEventIcon.h"
#import "RMEvent.h"

static const CGFloat eventIconSpacing = 68;
static const CGFloat currentEventIconSpacing = 12;
static const CGFloat eventIconCenterY = 42;

static const CGFloat currentEventArrowTop = 84;
static const CGFloat currentEventLabelTop = 120;

static const CGFloat otherEventIconScale = 0.6667;

@interface RMEventsView () <UIScrollViewDelegate>

@property (nonatomic, strong) NSMutableArray *eventIcons;
@property (nonatomic, strong) UIButton *addEventButton;

/**
 In order to have an indicator centered under the current icon,
 we have 3 views that scale: the left, center, and right, like such:
 ______________/\_____________
 ^left         ^center       ^right
*/
@property (nonatomic, strong) UIImageView *currentEventArrowLeft;
@property (nonatomic, strong) UIImageView *currentEventArrow;
@property (nonatomic, strong) UIImageView *currentEventArrowRight;

/** The title of the current event */
@property (nonatomic, strong) UILabel *currentEventLabel;

/** Readwrite */
@property (nonatomic, strong, readwrite) RMEvent *currentEvent;
@property (nonatomic, strong, readwrite) UIScrollView *scrollView;

@end

@implementation RMEventsView

- (id)initWithEvents:(NSArray *)events
{
    self = [super initWithFrame:CGRectMake(0, 0, [UIScreen mainScreen].bounds.size.width, 144)];
    if (self) {
        [self addSubview:self.scrollView];
        
        self.currentEventLabel.frame = CGRectMake(0, currentEventLabelTop, self.width, 28);
        [self addSubview:self.currentEventLabel];
        
        _events = events;
        self.eventIcons = [NSMutableArray arrayWithCapacity:events.count];
        
        for (int i = 0; i < events.count; i++) {
            RMEvent *event = events[i];
            RMEventIcon *eventIcon = [[RMEventIcon alloc] initWithEvent:event];
            [self addGestureRecognizersToEventIcon:eventIcon];
            [self.scrollView addSubview:eventIcon];
            [self.eventIcons addObject:eventIcon];
        }
        [self.scrollView addSubview:self.currentEventArrowLeft];
        [self.scrollView addSubview:self.currentEventArrow];
        [self.scrollView addSubview:self.currentEventArrowRight];
        
        _showsAddEventButton = YES;
        [self layoutForEvent:events[0]];
    }
    return self;
}

- (void)setShowsAddEventButton:(BOOL)showsAddEventButton
{
    _showsAddEventButton = showsAddEventButton;
    if (showsAddEventButton) {
        [self.scrollView addSubview:self.addEventButton];
    } else {
        [self.addEventButton removeFromSuperview];
    }
    
    [self layoutForEvent:self.currentEvent];
}

- (void)addEventIcon:(RMEventIcon *)eventIcon
{
    eventIcon.showsTitle = NO;
    [self.scrollView addSubview:eventIcon];
    [self.eventIcons addObject:eventIcon];
    [self addGestureRecognizersToEventIcon:eventIcon];
    
    [UIView animateWithDuration:0.35
                     animations:^{
                         CGFloat center = [self layoutForEvent:eventIcon.event];
                         self.centerX = 2*(self.width / 2.0) - (center - self.scrollView.contentOffset.x);
                     } completion:^(BOOL finished) {
                         self.scrollView.contentOffset = CGPointMake(-self.left + self.scrollView.contentOffset.x, 0);
                         self.left = 0;
                     }];
}

- (void)removeEventIcon:(RMEventIcon *)eventIcon
{
    NSInteger indexOfEventIcon = [self.eventIcons indexOfObject:eventIcon];
    // Do not delete if the event icon is not in there
    // Do not delete if there is only one event
    // Do not delete if not allowed to add more events as defined by mission
    if (indexOfEventIcon == NSNotFound
        || (self.eventIcons.count == 1)
        || !self.showsAddEventButton) {
        return;
    }
    [eventIcon removeFromSuperview];
    [self.eventIcons removeObjectAtIndex:indexOfEventIcon];
    RMEventIcon *nextEventIconToDisplay = (indexOfEventIcon == 0) ? [self.eventIcons objectAtIndex:0] : [self.eventIcons objectAtIndex:(indexOfEventIcon - 1)];
    [self.delegate eventsView:self didRemoveEvent:eventIcon.event];
    [UIView animateWithDuration:0.35
                     animations:^{
                         CGFloat center = [self layoutForEvent:nextEventIconToDisplay.event];
                         self.centerX = 2*(self.width / 2.0) - (center - self.scrollView.contentOffset.x);
                     } completion:^(BOOL finished) {
                         self.scrollView.contentOffset = CGPointMake(-self.left + self.scrollView.contentOffset.x, 0);
                         self.left = 0;
                     }];
    
}

#pragma mark - UIScrollViewDelegate

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    if (scrollView == self.scrollView) {
        CGFloat x = scrollView.contentOffset.x;
        
        if (x < 0) {
            self.currentEventArrowLeft.left = x;
            self.currentEventArrowLeft.width = self.currentEventArrow.left + ABS(x);
        } else if (x > scrollView.contentSize.width - scrollView.width) {
            self.currentEventArrowRight.width = x + scrollView.width - self.currentEventArrow.right;
        }
    }
}

#pragma mark - Private Properties

- (UIScrollView *)scrollView
{
    if (!_scrollView) {
        _scrollView = [[UIScrollView alloc] initWithFrame:self.bounds];
        _scrollView.bounces = YES;
        _scrollView.alwaysBounceHorizontal = YES;
        _scrollView.showsHorizontalScrollIndicator = NO;
        _scrollView.clipsToBounds = NO;
        _scrollView.delegate = self;
    }
    return _scrollView;
}

- (UIButton *)addEventButton
{
    if (!_addEventButton) {
        _addEventButton = [[UIButton alloc] initWithFrame:CGRectMake(0, 0, 60, 60)];
        [_addEventButton setImage:[UIImage imageNamed:@"eventAddButton.png"] forState:UIControlStateNormal];
    }
    return _addEventButton;
}

- (UIImageView *)currentEventArrowLeft
{
    if (!_currentEventArrowLeft) {
        _currentEventArrowLeft = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"currentEventStripe.png"]];
        _currentEventArrowLeft.frame = CGRectMake(0, 20 + currentEventArrowTop, 0, 29.0);
    }
    return _currentEventArrowLeft;
}

- (UIImageView *)currentEventArrow
{
    if (!_currentEventArrow) {
        _currentEventArrow = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"currentEventArrow.png"]];
        _currentEventArrow.top = currentEventArrowTop;
    }
    return _currentEventArrow;
}

- (UIImageView *)currentEventArrowRight
{
    if (!_currentEventArrowRight) {
        _currentEventArrowRight = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"currentEventStripe.png"]];
        _currentEventArrowRight.frame = CGRectMake(0, 20 + currentEventArrowTop, 0, 29.0);
    }
    return _currentEventArrowRight;
}

- (UILabel *)currentEventLabel
{
    if (!_currentEventLabel) {
        _currentEventLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _currentEventLabel.backgroundColor = [UIColor clearColor];
        _currentEventLabel.textColor = [UIColor whiteColor];
        _currentEventLabel.font = [UIFont mediumFont];
        _currentEventLabel.numberOfLines = 1;
        _currentEventLabel.minimumScaleFactor = 0.5;
        _currentEventLabel.adjustsFontSizeToFitWidth = YES;
        _currentEventLabel.textAlignment = NSTextAlignmentCenter;
    }
    return _currentEventLabel;
}

#pragma mark - Private Methods

/** Animates to center this event */
- (CGFloat)layoutForEvent:(RMEvent *)event
{
    self.currentEvent = event;
    
    CGFloat centerOfEvent = 0;
    CGFloat centerX = self.width / 2.0;
    for (RMEventIcon *eventIcon in self.eventIcons) {
        if ([eventIcon.event isEqual:event]) {
            eventIcon.transform = CGAffineTransformIdentity;;
            if (centerX == self.width / 2.0) {
                eventIcon.center = CGPointMake(centerX, eventIconCenterY);
            } else {
                eventIcon.center = CGPointMake(centerX + currentEventIconSpacing, eventIconCenterY);
            }
            centerOfEvent = eventIcon.centerX;
            centerX = eventIcon.centerX + eventIconSpacing + currentEventIconSpacing;
        } else {
            eventIcon.transform = CGAffineTransformMakeScale(otherEventIconScale, otherEventIconScale);
            eventIcon.center = CGPointMake(centerX, eventIconCenterY);
            centerX = eventIcon.centerX + eventIconSpacing;
        }
    }
    
    CGFloat width = centerX - eventIconSpacing + self.width / 2.0;
    if (self.showsAddEventButton) {
        self.addEventButton.center = CGPointMake(centerX, eventIconCenterY);
        width = self.addEventButton.centerX + self.width / 2.0;
    }
    self.scrollView.contentSize = CGSizeMake(width, self.height);
    
    // Reposition the _____/\_____ to be pointing to the new event
    self.currentEventArrow.centerX = centerOfEvent;
    self.currentEventArrowLeft.width = self.currentEventArrow.left;
    self.currentEventArrowRight.frame = CGRectMake(self.currentEventArrow.right, self.currentEventArrowRight.top,
                                                   self.scrollView.contentSize.width - self.currentEventArrow.right, self.currentEventArrowRight.height);
    
    self.currentEventLabel.text = [NSString stringWithFormat:@"%@:", event.readableName];
    
    return centerOfEvent;
}

- (void)handleEventTap:(UITapGestureRecognizer *)tap
{
    if ([tap.view isKindOfClass:[RMEventIcon class]]) {
        RMEventIcon *bubble = (RMEventIcon *)tap.view;
        RMEvent *event = bubble.event;
        
        if (event == self.currentEvent) {
            
        } else {
            BOOL fromLeft = [self.events indexOfObject:event] < [self.events indexOfObject:self.currentEvent];
            [self.delegate eventsView:self selectedEvent:event fromLeft:fromLeft];
            [UIView animateWithDuration:0.35
                             animations:^{
                                 CGFloat center = [self layoutForEvent:event];
                                 self.centerX = 2*(self.width / 2.0) - (center - self.scrollView.contentOffset.x);
                                 self.currentEventLabel.left = -self.left;
                             } completion:^(BOOL finished) {
                                 self.scrollView.contentOffset = CGPointMake(-self.left + self.scrollView.contentOffset.x, 0);
                                 self.left = 0;
                                 self.currentEventLabel.left = 0;
                             }];
        }
    }
}

- (void)handleEventDeleteGesture:(UIGestureRecognizer *)gesture
{
    if ([gesture.view isKindOfClass:[RMEventIcon class]]) {
        RMEventIcon *bubble = (RMEventIcon *)gesture.view;
        [self.delegate eventsView:self willRemoveEventIcon:bubble];
    }
}

- (void)addGestureRecognizersToEventIcon:(RMEventIcon *)eventIcon
{
    [eventIcon addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleEventTap:)]];
    UITapGestureRecognizer *doubleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleEventDeleteGesture:)];
    doubleTap.numberOfTapsRequired = 2;
    [eventIcon addGestureRecognizer:doubleTap];
}

@end
