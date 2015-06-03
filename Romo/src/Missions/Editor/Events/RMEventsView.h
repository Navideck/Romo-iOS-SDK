//
//  RMEventsView.h
//  Romo
//

#import <UIKit/UIKit.h>

@class RMEvent;
@class RMEventIcon;

@protocol RMEventsViewDelegate;

@interface RMEventsView : UIView

@property (nonatomic, weak) id<RMEventsViewDelegate> delegate;

/** The events being shown */
@property (nonatomic, strong, readonly) NSArray *events;

/** The one currently selected */
@property (nonatomic, strong, readonly) RMEvent *currentEvent;

/** The scroll view that all event icons are contained in */
@property (nonatomic, strong, readonly) UIScrollView *scrollView;

@property (nonatomic) BOOL showsAddEventButton;

@property (nonatomic, readonly) UIButton *addEventButton;

- (id)initWithEvents:(NSArray *)events;

- (void)addEventIcon:(RMEventIcon *)eventIcon;
- (void)removeEventIcon:(RMEventIcon *)eventIcon;

@end

@protocol RMEventsViewDelegate <NSObject>

/** 
 fromLeft says whether we tapped an event to the left of the old one
 */
- (void)eventsView:(RMEventsView *)eventsView selectedEvent:(RMEvent *)event fromLeft:(BOOL)fromLeft;
- (void)eventsView:(RMEventsView *)eventsView willRemoveEventIcon:(RMEventIcon *)eventIcon;
- (void)eventsView:(RMEventsView *)eventsView didRemoveEvent:(RMEvent *)event;

@end