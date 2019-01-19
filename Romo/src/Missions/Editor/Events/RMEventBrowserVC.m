//
//  RMEventsBrowserVC.m
//  Romo
//

#import "RMEventBrowserVC.h"
#import "UIView+Additions.h"
#import "RMEventBrowserView.h"
#import "RMEvent.h"
#import "RMEventIcon.h"
#import "RMParameter.h"

@interface RMEventBrowserVC ()

@property (nonatomic, strong) RMEventBrowserView *view;

@property (nonatomic, getter=isLayedOutForOptions) BOOL layedOutForOptions;

@end

@implementation RMEventBrowserVC

@dynamic view;

- (void)loadView
{
    self.view = [[RMEventBrowserView alloc] initWithFrame:[UIScreen mainScreen].bounds];
    [self.view.dismissButton addTarget:self action:@selector(handleDismissButtonTouch:) forControlEvents:UIControlEventTouchUpInside];
}

- (void)setAvailableEvents:(NSArray *)availableEvents
{
    _availableEvents = availableEvents;
    
    NSMutableArray *eventIcons = [NSMutableArray arrayWithCapacity:availableEvents.count];
    [availableEvents enumerateObjectsUsingBlock:^(RMEvent *event, NSUInteger index, BOOL *stop) {
        RMEventIcon *eventIcon = [[RMEventIcon alloc] initWithEvent:event];
        [eventIcon addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleEventTap:)]];
        eventIcon.showsTitle = YES;
        [eventIcons addObject:eventIcon];
    }];
    self.view.eventIcons = eventIcons;
}

#pragma mark - Private Methods

- (void)handleEventTap:(UITapGestureRecognizer *)tap
{
    if ([tap.view isKindOfClass:[RMEventIcon class]]) {
        RMEventIcon *eventIcon = (RMEventIcon *)tap.view;
        RMEvent *event = eventIcon.event;
        
        if (!self.isLayedOutForOptions && event.parameter) {
            // If the event has a parameter, present the parameter options
            self.layedOutForOptions = YES;
            
            // Only show options that aren't explicitly excluded
            NSMutableArray *options = [NSMutableArray arrayWithArray:event.parameter.valueOptions];
            [self.excludingEvents enumerateObjectsUsingBlock:^(RMEvent *excludingEvent, NSUInteger idx, BOOL *stop) {
                if (excludingEvent.type == event.type) {
                    [options removeObject:excludingEvent.parameter.value];
                }
            }];
            NSMutableArray *optionIcons = [NSMutableArray arrayWithCapacity:options.count];
            
            // Create icons for each option
            for (id option in options) {
                RMEvent *eventOption = event.copy;
                eventOption.parameter.value = option;
                
                RMEventIcon *optionIcon = [[RMEventIcon alloc] initWithEvent:eventOption];
                optionIcon.showsTitle = YES;
                optionIcon.title = [[NSBundle mainBundle] localizedStringForKey:option value:option table:@"Extras"];
                [optionIcon addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleEventTap:)]];
                [optionIcons addObject:optionIcon];
            }
            
            NSString *eventTitle = [[RMEvent readableNameForEventType:event.type] stringByReplacingOccurrencesOfString:@"$" withString:@"..."];
            self.view.titleLabel.text = eventTitle;
            [self.view layoutForEventIconOptions:optionIcons];
        } else {
            // Otherwise, notify the delegate immediately
            [self.delegate eventBrowser:self selectedEvent:[eventIcon.event copy] withEventIcon:eventIcon];
        }
    }
}

- (void)handleDismissButtonTouch:(UIButton *)dismissButton
{
    [self.delegate eventBrowserDidDismiss:self];
}

@end
