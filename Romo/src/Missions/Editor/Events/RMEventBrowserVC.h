//
//  RMEventsBrowserVC.h
//  Romo
//

#import <UIKit/UIKit.h>

@class RMEvent;
@class RMEventIcon;

@protocol RMEventBrowserVCDelegate;

@interface RMEventBrowserVC : UIViewController

@property (nonatomic, weak) id<RMEventBrowserVCDelegate> delegate;

/** The events to be shown */
@property (nonatomic, strong) NSArray *availableEvents;

/** Events & parameters not shown */
@property (nonatomic, strong) NSArray *excludingEvents;

@end

@protocol RMEventBrowserVCDelegate <NSObject>

- (void)eventBrowser:(RMEventBrowserVC *)eventBrowser selectedEvent:(RMEvent *)event withEventIcon:(RMEventIcon *)eventIcon;
- (void)eventBrowserDidDismiss:(RMEventBrowserVC *)eventBrowser;

@end