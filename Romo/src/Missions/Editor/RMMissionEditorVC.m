//
//  RMMissionEditorVC.h
//  Romo
//

#import "RMMissionEditorVC.h"
#import "UIView+Additions.h"
//#import <Analytics/Analytics.h>
#import <Romo/RMShared.h>
#import "RMMission.h"
#import "RMAction.h"
#import "RMEvent.h"
#import "RMEventsView.h"
#import "RMActionRuntime.h"
#import "RMActionIcon.h"
#import "RMActionView.h"
#import "RMMissionEditorView.h"
#import "RMActionBrowserVC.h"
#import "RMSlideToStart.h"
#import "RMSoundEffect.h"
#import "RMEventBrowserVC.h"
#import "RMEventIcon.h"

#define solveButtonSound    @"Missions-Editor-Accept"
#define themeSound          @"Missions-Editor-Theme"
#define editDisabledSound   @"Missions-Editor-Action-Edit-Disabled"
#define editStartSound      @"Missions-Editor-Action-Edit-Start"
#define editStopSound       @"Missions-Editor-Action-Edit-Stop"
#define addButtonSound      @"Missions-Editor-Add"
#define addActionSound      @"Missions-Editor-Add-Action"

static const int kEventDeleteConfirmAlertViewTag = 1001;

typedef enum {
    RMMissionEditorVCStartButtonChangeNone = 0,
    RMMissionEditorVCStartButtonChangeShown = 1,
    RMMissionEditorVCStartButtonChangeHidden = 2,
} RMMissionEditorVCStartButtonChange;

@interface RMMissionEditorVC () <RMActionViewDelegate, UIScrollViewDelegate, RMEventsViewDelegate, RMEventBrowserVCDelegate, RMActionBrowserDelegate, RMSlideToStartDelegate, UIAlertViewDelegate>

/** The event currently being edited */
@property (nonatomic, strong) RMEvent *currentEvent;

/** The script currently being edited */
@property (nonatomic, strong) NSMutableArray *currentScript;

/** Script view for our event */
@property (nonatomic, strong) RMMissionEditorView *view;

/** A browser of available events shown when the add event button is tapped */
@property (nonatomic, strong) RMEventBrowserVC *eventBrowserVC;

/** A browser of available actions shown when the add button is tapped */
@property (nonatomic, strong) RMActionBrowserVC *actionBrowserVC;

/** A helper that prevents sound clashes when selecting an event */
@property (nonatomic) BOOL skipScrollSound;

@end

@implementation RMMissionEditorVC

@dynamic view;

- (void)loadView
{
    self.view = [[RMMissionEditorView alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.view.delegate = self;
    self.view.actionViewDelegate = self;
    self.view.slideToStart.slideDelegate = self;
    self.view.clipsToBounds = NO;
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];

    [UIView animateWithDuration:0.25 delay:0 options:UIViewAnimationOptionCurveEaseOut
                     animations:^{
                         self.delegate.navigationBar.top = 0;
                     } completion:nil];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Try to prevent a low-memory crash by disposing of resources
    [self dismissActionBrowserPreanimation];
    [self dismissActionBrowserAnimation];
    [self dismissActionBrowserCompletion];
    
    if (_eventBrowserVC) {
        [self.eventBrowserVC.view removeFromSuperview];
        [self.eventBrowserVC removeFromParentViewController];
        self.eventBrowserVC = nil;
        self.view.scrollEnabled = YES;
    }
    
    [RMSoundEffect stopForegroundEffect];
    [RMSoundEffect stopBackgroundEffect];
}

#pragma mark - Public Properties

- (void)setMission:(RMMission *)mission
{
    _mission = mission;

    // If we allow adding events or there are events other than on-start, show the event bubble(s)
    RMEventType firstEventType = self.mission.events.count > 0 ? ((RMEvent *)self.mission.events[0]).type : RMEventMissionStart;
    self.view.showsEvents = self.mission.events.count > 1 || self.mission.allowsAddingEvents || (firstEventType != RMEventMissionStart);
    
    self.view.mission = mission;

    if (self.view.showsEvents) {
        self.view.eventsView.showsAddEventButton &= self.mission.allowsAddingEvents;
    }
    
    self.view.briefingWindow.centerX = self.view.width / 2.0;
    [self.view addSubview:self.view.briefingWindow];
    [self.view.solveButton addTarget:self action:@selector(handleSolveButtonTouch:) forControlEvents:UIControlEventTouchUpInside];
    
    [self.view layoutDidChange];
    
    if (mission.skipBriefing) {
        [self handleSolveButtonTouch:nil];
    }
}

#pragma mark - RMEventsBrowserVCDelegate

- (void)eventBrowser:(RMEventBrowserVC *)eventBrowser selectedEvent:(RMEvent *)event withEventIcon:(RMEventIcon *)eventIcon
{    
    eventIcon.event = event;
    eventIcon.top = eventBrowser.view.top + eventIcon.top - self.view.eventsView.top;
    eventIcon.left += self.view.eventsView.scrollView.contentOffset.x;
    [eventIcon removeAllGestureRecognizers];
    
    // Add the new event to the model, as well as an empty script for that event
    [self.mission.events addObject:event];
    [self.mission.inputScripts addObject:[NSMutableArray array]];
    
    // Toggle + button if we have more events left or not
    self.view.eventsView.showsAddEventButton = ([self remainingEvents].count > 0);

    [self dismissEventBrowser];
    [self.view.eventsView addEventIcon:eventIcon];
    [self eventsView:self.view.eventsView selectedEvent:event fromLeft:NO];
}

- (void)eventBrowserDidDismiss:(RMEventBrowserVC *)eventBrowser
{
    [self dismissEventBrowser];
}

#pragma mark - RMActionBrowserDelegate

- (void)actionBrowser:(RMActionBrowserVC *)browser didSelectIcon:(RMActionIcon *)icon withAction:(RMAction *)action
{
    icon.top += browser.view.top;
    [self.view addSubview:icon];

    [self.currentScript addObject:action];
    [self.mission decrementAvailableCountForAction:action];

    CGFloat addButtonTop = self.view.addActionButton.top;
    CGFloat plusArrowTop = self.view.addActionArrow.top;

    RMActionView *actionView = [self.view addAction:action];
    [self.view layoutDidChange];
    CGPoint oldCenter = actionView.center;
    actionView.transform = CGAffineTransformMakeScale(1.0 / 3.35, 1.0 / 1.75);
    actionView.center = CGPointMake(icon.centerX, icon.centerY - 20);
    actionView.alpha = 0.5;

    [self dismissActionBrowserPreanimation];
    [RMSoundEffect playForegroundEffectWithName:addActionSound repeats:NO gain:1.0];

    BOOL removesAddButton = NO;
    BOOL hasMaximumNumberOfActions = (self.mission.maximumActionCount > -1) && (self.currentScript.count >= self.mission.maximumActionCount);
    if (self.mission.allowsAddingActions && !hasMaximumNumberOfActions) {
        CGFloat targetTop = self.view.addActionButton.top;
        self.view.addActionButton.top = addButtonTop;
        addButtonTop = targetTop;

        targetTop = self.view.addActionArrow.top;
        self.view.addActionArrow.top = plusArrowTop;
        plusArrowTop = targetTop;
    } else {
        removesAddButton = YES;
    }

    [[UIApplication sharedApplication] beginIgnoringInteractionEvents];
    [UIView animateWithDuration:0.35
                     animations:^{
                         icon.transform = CGAffineTransformMakeScale(3.35, 1.55);
                         icon.alpha = 0.0;
                         icon.center = CGPointMake(oldCenter.x, oldCenter.y + 20);
                         [icon layoutForExpansion];

                         actionView.transform = CGAffineTransformIdentity;
                         actionView.alpha = 1.0;
                         actionView.center = oldCenter;

                         self.view.addActionButton.top = addButtonTop;
                         self.view.addActionArrow.top = plusArrowTop;

                         [self dismissActionBrowserAnimation];

                         if (removesAddButton) {
                             self.view.addActionButton.alpha = 0.0;
                             self.view.addActionArrow.alpha = 0.0;
                         }
                     } completion:^(BOOL finished) {
                         [icon removeFromSuperview];
                         [self dismissActionBrowserCompletion];

                         if (self.mission.glowActionViews) {
                             actionView.glowing = YES;
                         }

                         if (removesAddButton) {
                             [self toggleAddButton];
                         }

                         if ([self toggleSlideToStart] == RMMissionEditorVCStartButtonChangeShown) {
                             [self scrollToBottom];
                         }

                         [[UIApplication sharedApplication] endIgnoringInteractionEvents];
                     }];
}

#pragma mark - RMActionViewDelegate

/** 
 Expand an action view for editing if it isn't already
 Otherwise collapse it down
 */
- (void)toggleEditingForActionView:(RMActionView *)actionView
{
    if (!self.mission.allowsEditingParameters || !actionView.parameters.count || actionView.isLocked) {
        [RMSoundEffect playForegroundEffectWithName:editDisabledSound repeats:NO gain:1.0];
        [self pulseActionView:actionView];
        return;
    }

    BOOL expanding = !actionView.isEditing;
    self.view.scrollEnabled = !expanding;
    actionView.glowing = NO;

    NSInteger index = [self.view.actionViews indexOfObject:actionView];
    CGFloat offset = self.view.height / 2;
    [[UIApplication sharedApplication] beginIgnoringInteractionEvents];
    if (expanding) {
        // dismiss the action browser
        // (doesn't play nice with the animation, so we do it first)
        [self dismissActionBrowserPreanimation];
        [self dismissActionBrowserAnimation];
        [self dismissActionBrowserCompletion];

        // store the top position of the actionView before
        // it is expanded to full screen so we can animate it back
        // into place later
        actionView.tag = actionView.top;
        [actionView willLayoutForEditing:YES];
        actionView.height = [UIScreen mainScreen].bounds.size.height;

        [RMSoundEffect playForegroundEffectWithName:editStartSound repeats:NO gain:1.0];
        [UIView animateWithDuration:0.35
                         animations:^{
                             for (int i = 0; i < self.view.actionViews.count; i++) {
                                 RMActionView *otherView = self.view.actionViews[i];
                                 if (otherView != actionView) {
                                     otherView.top += offset * (i < index ? -1 : 1);
                                     otherView.alpha = 0.0;
                                 }
                             }
                             actionView.top = self.view.contentOffset.y;
                             actionView.editing = YES;

                             self.view.addActionButton.top += offset;
                             self.view.addActionButton.alpha = 0.0;
                             self.view.slideToStart.top += offset;
                             
                             if (self.view.showsEvents) {
                                 self.view.eventsView.alpha = 0.0;
                             }
                             
                             if (self.mission.allowsRepeat) {
                                 self.view.repeatButton.top += offset;
                                 self.view.repeatButton.alpha = 0.0;
                             }
                             
                             self.delegate.navigationBar.bottom = 0;
                         } completion:^(BOOL finished) {
                             [actionView didLayoutForEditing:YES];

                             // remove all invisible views
                             for (RMActionView *otherView in self.view.actionViews) {
                                 if (otherView != actionView) {
                                     [otherView removeFromSuperview];
                                 }
                             }
                             [self.view.addActionButton removeFromSuperview];
                             [self.view.slideToStart removeFromSuperview];
                             [[UIApplication sharedApplication] endIgnoringInteractionEvents];
                         }];
    } else {
        // readd all views before animation
        for (RMActionView *otherView in self.view.actionViews) {
            [self.view addSubview:otherView];
        }
        [self toggleAddButton];
        [self.view addSubview:self.view.slideToStart];
        
        [self.mission updateAvailableActionsToMatchAction:self.currentScript[index]];

        [RMSoundEffect playForegroundEffectWithName:editStopSound repeats:NO gain:1.0];

        [actionView willLayoutForEditing:NO];
        [self dismissActionBrowserPreanimation];
        [UIView animateWithDuration:0.35
                         animations:^{
                             for (int i = 0; i < self.view.actionViews.count; i++) {
                                 RMActionView *otherView = self.view.actionViews[i];
                                 if (otherView != actionView) {
                                     otherView.top -= offset * (i < index ? -1 : 1);
                                     otherView.alpha = 1.0;
                                 }
                             }
                             actionView.top = actionView.tag;
                             actionView.editing = NO;

                             self.view.addActionButton.top -= offset;
                             self.view.addActionButton.alpha = 1.0;
                             self.view.slideToStart.top -= offset;
                             
                             if (self.view.showsEvents) {
                                 self.view.eventsView.alpha = 1.0;
                             }
                             
                             if (self.mission.allowsRepeat) {
                                 self.view.repeatButton.top -= offset;
                                 self.view.repeatButton.alpha = 1.0;
                             }
                             
                             [self scrollViewDidScroll:self.view];
                         } completion:^(BOOL finished) {
                             actionView.height = actionViewHeight;
                             [actionView didLayoutForEditing:NO];
                             [self.view layoutDidChange];
                             [[UIApplication sharedApplication] endIgnoringInteractionEvents];
                         }];
    }
}

/**
 If an action view is tapped but can't be edited, we bounce it to recognize affordance
 */
- (void)pulseActionView:(RMActionView *)actionView
{
    NSInteger index = [self.view.actionViews indexOfObject:actionView];
    [[UIApplication sharedApplication] beginIgnoringInteractionEvents];
    [UIView animateWithDuration:0.25
                     animations:^{
                         actionView.transform = CGAffineTransformMakeScale(1.2, 1.2);

                         int i = 0;
                         for (RMActionView *otherView in self.view.actionViews) {
                             if (otherView != actionView) {
                                 otherView.top += 40 * (i < index ? -1 : 1);
                             }
                             i++;
                         }
                         self.view.addActionButton.top += 40;
                         if (self.mission.allowsRepeat) {
                             self.view.repeatButton.top += 40.0;
                         }
                     } completion:^(BOOL finished) {
                         [UIView animateWithDuration:0.25
                                          animations:^{
                                              actionView.transform = CGAffineTransformMakeScale(0.9, 0.9);

                                              int i = 0;
                                              for (RMActionView *otherView in self.view.actionViews) {
                                                  if (otherView != actionView) {
                                                      otherView.top -= 55 * (i < index ? -1 : 1);
                                                  }
                                                  i++;
                                              }
                                              self.view.addActionButton.top -= 55;
                                              if (self.mission.allowsRepeat) {
                                                  self.view.repeatButton.top -= 55.0;
                                              }
                                          } completion:^(BOOL finished) {
                                              [UIView animateWithDuration:0.25
                                                               animations:^{
                                                                   actionView.transform = CGAffineTransformIdentity;

                                                                   int i = 0;
                                                                   for (RMActionView *otherView in self.view.actionViews) {
                                                                       if (otherView != actionView) {
                                                                           otherView.top += 15 * (i < index ? -1 : 1);
                                                                       }
                                                                       i++;
                                                                   }
                                                                   self.view.addActionButton.top += 15;
                                                                   if (self.mission.allowsRepeat) {
                                                                       self.view.repeatButton.top += 15.0;
                                                                   }
                                                               } completion:^(BOOL finished) {
                                                                   [[UIApplication sharedApplication] endIgnoringInteractionEvents];
                                                               }];
                                          }];
                     }];
}

- (void)actionViewDidDelete:(RMActionView *)actionView
{
    [RMSoundEffect playForegroundEffectWithName:deleteButtonSound repeats:NO gain:1.0];
    NSInteger index = [self.view.actionViews indexOfObject:actionView];
    RMAction *deletedAction = self.currentScript[index];
    [self.currentScript removeObjectAtIndex:index];
    [self.view.actionViews removeObject:actionView];

    [self.mission incrementAvailableCountForAction:deletedAction];

    for (RMActionView *otherView in self.view.actionViews) {
        if (otherView != actionView) {
            [self.view addSubview:otherView];
        }
    }
    [self toggleAddButton];
    [UIView animateWithDuration:0.25
                     animations:^{
                         actionView.alpha = 0.0;
                         actionView.centerY -= actionView.height / 2.0;
                         actionView.transform = CGAffineTransformMakeScale(1.0, 0.001);

                         [self.view layoutDidChange];

                         [self dismissActionBrowser];
                     } completion:^(BOOL finished) {
                         actionView.glowing = NO;
                         [actionView removeFromSuperview];
                         if ([self toggleSlideToStart] == RMMissionEditorVCStartButtonChangeShown) {
                             [self scrollToBottom];
                         }
                         self.view.scrollEnabled = YES;
                     }];
}

- (void)actionViewDidTouchConfirm:(RMActionView *)actionView
{
    [self toggleEditingForActionView:actionView];
}

- (void)actionView:(RMActionView *)actionView didDragByOffset:(CGPoint)offset fromOrigin:(CGPoint)origin
{
    [self dismissActionBrowser];
    [self.view actionView:actionView didDragByOffset:offset fromOrigin:origin];
}

- (void)actionView:(RMActionView *)actionView didEndDragging:(CGPoint)offset fromOrigin:(CGPoint)origin
{
    NSInteger oldIndex = [self.view.actionViews indexOfObject:actionView];
    RMAction *correspondingAction = self.currentScript[oldIndex];

    int index = [self.view actionView:actionView didEndDragging:offset fromOrigin:origin];

    [self.currentScript removeObject:correspondingAction];
    [self.currentScript insertObject:correspondingAction atIndex:index];
}

#pragma mark - RMEventsViewDelegate

- (void)eventsView:(RMEventsView *)eventsView selectedEvent:(RMEvent *)event fromLeft:(BOOL)fromLeft
{
    // Play random swish sound
    if (!self.skipScrollSound) {
        int randomSwishNum = arc4random_uniform(kNumSwishSounds) + 1;
        [RMSoundEffect playForegroundEffectWithName:[NSString stringWithFormat:@"Swish-%d", randomSwishNum]
                                            repeats:NO
                                               gain:1.0];
    } else {
        self.skipScrollSound = NO;
    }

    CGFloat offset = (fromLeft ? 1 : -1) * self.view.width;
    [UIView animateWithDuration:0.15 delay:0 options:UIViewAnimationOptionCurveEaseIn
                     animations:^{
                         // Slide the old views out in the proper direction...
                         for (RMActionView *actionView in self.view.actionViews) {
                             actionView.left += offset;
                         }
                         self.view.addActionButton.left += offset;
                         self.view.addActionArrow.left += offset;
                         self.view.actionBrowserVC.view.left += offset;
                         
                         if (self.mission.allowsRepeat) {
                             self.view.repeatButton.left += offset;
                         }
                     } completion:^(BOOL finished) {
                         // ...then reposition all the new views on the other side of the screen...
                         self.view.addActionButton.centerX = self.view.width / 2.0;
                         self.view.addActionArrow.centerX = self.view.width / 2.0;
                         self.view.actionBrowserVC.view.centerX = self.view.width / 2.0;
                         [self dismissActionBrowserPreanimation];
                         [self dismissActionBrowserAnimation];
                         [self dismissActionBrowserCompletion];
                         
                         self.currentEvent = event;
                         
                         for (RMActionView *actionView in self.view.actionViews) {
                             actionView.left -= offset;
                         }
                         [UIView animateWithDuration:0.15 delay:0 options:UIViewAnimationOptionCurveEaseOut
                                          animations:^{
                                              // ...then reanimate them in from the opposite side that the old went out
                                              for (RMActionView *actionView in self.view.actionViews) {
                                                  actionView.left += offset;
                                              }
                                          } completion:^(BOOL finished) {
                                              
                                          }];
                     }];
}

- (void)eventsView:(RMEventsView *)eventsView willRemoveEventIcon:(RMEventIcon *)eventIcon
{
    NSInteger indexOfEvent = [self.mission.events indexOfObject:eventIcon.event];
    // ONLY allow deletion message to appear if:
    // the event is in the pool
    // there is more than one event
    // mission allows adding events
    if (indexOfEvent != NSNotFound && self.mission.events.count > 1 && self.mission.allowsAddingEvents) {
        NSMutableArray *eventInputScripts = (NSMutableArray *)[self.mission.inputScripts objectAtIndex:indexOfEvent];
        // If the event has more than one action in it, ask before deleting
        if (eventInputScripts.count > 0) {
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"MissionEditor-DeleteEvent-Alert-Title", @"Delete Event?")
                                                            message:NSLocalizedString(@"MissionEditor-DeleteEvent-Alert-Message", @"Are you sure you want to delete this event?")
                                                           delegate:self
                                                  cancelButtonTitle:NSLocalizedString(@"MissionEditor-DeleteEvent-Alert-Yes", @"Delete")
                                                  otherButtonTitles:NSLocalizedString(@"MissionEditor-DeleteEvent-Alert-No", @"Cancel"), nil];
            alert.tag = kEventDeleteConfirmAlertViewTag;
            [alert show];
        } else {
            [self.view.eventsView removeEventIcon:eventIcon];
        }
    }
}

- (void)eventsView:(RMEventsView *)eventsView didRemoveEvent:(RMEvent *)event
{
    NSInteger indexOfEvent = [self.mission.events indexOfObject:event];
    if (indexOfEvent != NSNotFound) {
        // Remove event from mission
        [self.mission.events removeObjectAtIndex:indexOfEvent];
        [self.mission.inputScripts removeObjectAtIndex:indexOfEvent];
        // Find the next event to display and shift the views over
        RMEvent *nextEventToDisplay = (indexOfEvent == 0) ? [self.mission.events objectAtIndex:0] : [self.mission.events objectAtIndex:(indexOfEvent - 1)];
        [self eventsView:self.view.eventsView selectedEvent:nextEventToDisplay fromLeft:NO];
    }
}

#pragma mrk - UIScrollViewDelegate

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    if (scrollView == self.view) {
        self.delegate.navigationBar.top = MIN(0, -self.view.contentOffset.y);

        CGRect visibleRect = (CGRect){ self.view.contentOffset, self.view.size };

        // remove invisible action views as we scroll which causes them to stop animating
        for (RMActionView *actionView in self.view.actionViews) {
            BOOL isVisible = CGRectIntersectsRect(visibleRect, actionView.frame);
            if (isVisible && !actionView.superview) {
                [self.view addSubview:actionView];
            } else if (!isVisible && actionView.superview) {
                [actionView removeFromSuperview];
            }
        }
    }
}

#pragma mark - RMSlideToStartDelegate

- (void)slideToStart:(RMSlideToStart *)slideToStart
{
    [self.delegate handleMissionEditorDidStart:self];
}

#pragma mark - UIAlertViewDelegate -

- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex
{
    if (alertView.tag == kEventDeleteConfirmAlertViewTag) {
        // Find the eventIcon with the current event
        if (buttonIndex == 0) {
            // Find the eventIcon with the current event
            for (UIView *view in self.view.eventsView.scrollView.subviews) {
                if ([view isKindOfClass:[RMEventIcon class]]) {
                    RMEventIcon *eventIcon = (RMEventIcon *)view;
                    if (eventIcon.event == self.currentEvent) {
                        [self.view.eventsView removeEventIcon:eventIcon];
                        break;
                    }
                }
            }
        }
    }
}

#pragma mark - UI State

- (void)setCurrentEvent:(RMEvent *)currentEvent
{
    _currentEvent = currentEvent;

    NSInteger index = [self.mission.events indexOfObject:currentEvent];
    self.currentScript = self.mission.inputScripts[index];
    self.view.script = self.currentScript;
    
    [self.currentScript enumerateObjectsUsingBlock:^(RMAction *action, NSUInteger idx, BOOL *stop) {
        [self.mission updateAvailableActionsToMatchAction:action];
    }];
    
    [self updateRepeatButton];
}

/**
 Determines whether or not the add button should be visible
 */
- (void)toggleAddButton
{
    BOOL hasMaximumNumberOfActions = (self.mission.maximumActionCount > -1) && (self.currentScript.count >= self.mission.maximumActionCount);
    if (self.mission.allowsAddingActions && !hasMaximumNumberOfActions) {
        [self.view insertSubview:self.view.addActionButton atIndex:0];
        [self.view.addActionArrow removeFromSuperview];
        self.view.addActionArrow = nil;

        [self.view.addActionButton addTarget:self action:@selector(handleAddButtonTouch:) forControlEvents:UIControlEventTouchUpInside];
    } else {
        [self.view.addActionButton removeFromSuperview];
        [self.view.addActionArrow removeFromSuperview];
        self.view.addActionButton = nil;
        self.view.addActionArrow = nil;
    }
}

- (RMMissionEditorVCStartButtonChange)toggleSlideToStart
{
    BOOL hasActions = NO;
    for (NSArray *script in self.mission.inputScripts) {
        if (script.count > 0) {
            hasActions = YES;
        }
    }
    
    BOOL shouldShowSlideToStart = (!self.mission.allowsAddingActions || hasActions);
    if (shouldShowSlideToStart && !self.view.slideToStart.superview) {
        self.view.slideToStart.top = self.view.contentSize.height;
        [self.view addSubview:self.view.slideToStart];
        [self.view layoutDidChange];
        
        return RMMissionEditorVCStartButtonChangeShown;
    } else if (!shouldShowSlideToStart) {
        [UIView animateWithDuration:0.35 delay:0.0 options:UIViewAnimationOptionCurveEaseIn
                         animations:^{
                             self.view.slideToStart.top = self.view.contentSize.height;
                         } completion:^(BOOL finished) {
                             [self.view layoutDidChange];
                             [self.view.slideToStart removeFromSuperview];
                         }];
        
        return RMMissionEditorVCStartButtonChangeHidden;
    } else {
        return RMMissionEditorVCStartButtonChangeNone;
    }
}

#pragma mark - Event Browser

- (RMEventBrowserVC *)eventBrowserVC
{
    if (!_eventBrowserVC) {
        _eventBrowserVC = [[RMEventBrowserVC alloc] init];
        _eventBrowserVC.delegate = self;
    }
    return _eventBrowserVC;
}

- (NSArray *)remainingEvents
{
    NSMutableArray *remainingEvents = [NSMutableArray arrayWithCapacity:self.mission.availableEvents.count];
    for (RMEvent *event in self.mission.availableEvents) {
        int currentCount = 0;
        int maximumCount = [RMEvent maximumCountForEventType:event.type];
        for (RMEvent *existingEvent in self.mission.events) {
            if (existingEvent.type == event.type) {
                currentCount++;
            }
        }
        if (currentCount < maximumCount) {
            [remainingEvents addObject:event];
        }
    }
    return remainingEvents;
}

- (void)presentEventBrowser
{
    [RMSoundEffect playForegroundEffectWithName:addButtonSound repeats:NO gain:1.0];

    self.eventBrowserVC.view.center = CGPointMake(self.view.eventsView.addEventButton.centerX - self.view.eventsView.scrollView.contentOffset.x,
                                                  self.view.eventsView.top + self.view.eventsView.addEventButton.centerY);
    self.eventBrowserVC.view.alpha = 0.5;
    self.eventBrowserVC.view.transform = CGAffineTransformMakeScale(0.1, 0.1);
    
    self.eventBrowserVC.availableEvents = [self remainingEvents];
    self.eventBrowserVC.excludingEvents = self.mission.events;
    [self addChildViewController:self.eventBrowserVC];
    [self.view addSubview:self.eventBrowserVC.view];

    self.view.scrollEnabled = NO;
    [UIView animateWithDuration:0.25
                     animations:^{
                         self.eventBrowserVC.view.alpha = 1.0;
                         self.eventBrowserVC.view.transform = CGAffineTransformIdentity;
                         self.eventBrowserVC.view.center = CGPointMake(self.view.width / 2.0, self.view.height / 2.0 + self.view.contentOffset.y);
                     } completion:^(BOOL finished) {
                     }];
}

- (void)dismissEventBrowser
{
    self.skipScrollSound = YES;
    [RMSoundEffect playForegroundEffectWithName:generalButtonSound repeats:NO gain:1.0];

    [UIView animateWithDuration:0.35
                     animations:^{
                         self.eventBrowserVC.view.alpha = 0.0;
                         self.eventBrowserVC.view.transform = CGAffineTransformMakeScale(0.1, 0.1);
                         self.eventBrowserVC.view.center = CGPointMake(self.view.eventsView.addEventButton.centerX - self.view.eventsView.scrollView.contentOffset.x, self.view.eventsView.top + self.view.eventsView.addEventButton.centerY);
                     } completion:^(BOOL finished) {
                         [self.eventBrowserVC.view removeFromSuperview];
                         [self.eventBrowserVC removeFromParentViewController];
                         self.eventBrowserVC = nil;
                         
                         self.view.scrollEnabled = YES;
                     }];
}

#pragma mark - Animating

- (void)scrollToBottom
{
    [UIView animateWithDuration:0.35 delay:0.0 options:UIViewAnimationOptionCurveEaseOut
                     animations:^{
                         [self.view layoutDidChange];
                         self.view.top = self.view.height - self.view.contentSize.height + self.view.contentOffset.y;
                         
                         self.delegate.navigationBar.top = self.view.top;
                     } completion:^(BOOL finished) {
                         self.view.top = 0;
                         self.view.contentOffset = CGPointMake(0, self.view.contentSize.height - self.view.height);
                     }];
}

#pragma mark - Action Browser

- (RMActionBrowserVC *)actionBrowserVC
{
    if (!_actionBrowserVC) {
        _actionBrowserVC = [[RMActionBrowserVC alloc] init];
        _actionBrowserVC.delegate = self;
        _actionBrowserVC.availableActions = self.mission.availableActions;
    }
    return _actionBrowserVC;
}

- (void)presentActionBrowser
{
    self.actionBrowserVC.view.top = self.view.addActionButton.top + 172;
    self.actionBrowserVC.view.alpha = 0.0;
    [self addChildViewController:self.actionBrowserVC];
    [self.view addSubview:self.actionBrowserVC.view];

    [self.view insertSubview:self.view.addActionArrow atIndex:0];
    self.view.addActionArrow.alpha = 0.0;

    [RMSoundEffect playForegroundEffectWithName:addButtonSound repeats:NO gain:1.0];

    CGFloat scrollViewFinalHeight = self.view.addActionButton.top + 90 + self.actionBrowserVC.view.height - self.view.height;
    CGFloat scrollToOffsetY = CLAMP(0, self.view.addActionArrow.top - topYGap, scrollViewFinalHeight);

    [[UIApplication sharedApplication] beginIgnoringInteractionEvents];
    [UIView animateWithDuration:0.35
                     animations:^{
                         self.view.addActionArrow.alpha = 1.0;
                         self.view.addActionButton.alpha = 0.0;

                         self.actionBrowserVC.view.top = self.view.addActionButton.top + 90;
                         self.actionBrowserVC.view.alpha = 1.0;
                         self.view.actionBrowserVC = self.actionBrowserVC;
                         self.view.top = -scrollToOffsetY + self.view.contentOffset.y;
                         
                         if (self.mission.allowsRepeat) {
                             self.view.repeatButton.alpha = 0.0;
                         }

                         self.delegate.navigationBar.top = self.view.top;
                     } completion:^(BOOL finished) {
                         self.view.top = 0;
                         self.view.contentOffset = CGPointMake(0, scrollToOffsetY);
                         [self.view.addActionArrow addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleAddButtonTouch:)]];
                         [[UIApplication sharedApplication] endIgnoringInteractionEvents];
                     }];
}

- (void)dismissActionBrowser
{
    if (_actionBrowserVC.view.superview) {
        [self dismissActionBrowserPreanimation];
        [UIView animateWithDuration:0.35
                         animations:^{
                             [self dismissActionBrowserAnimation];
                         } completion:^(BOOL finished) {
                             [self dismissActionBrowserCompletion];
                         }];
    }
}

- (void)dismissActionBrowserPreanimation
{
    if (_actionBrowserVC.view.superview) {
        [self.view insertSubview:self.view.addActionButton atIndex:0];
        self.view.addActionButton.alpha = 0.0;

        for (RMActionView *actionView in self.view.actionViews) {
            [self.view addSubview:actionView];
        }
    }
}

- (void)dismissActionBrowserAnimation
{
    if (_actionBrowserVC.view.superview) {
        self.view.addActionButton.alpha = 1.0;
        self.view.addActionArrow.alpha = 0.0;

        self.view.delegate = nil;
        CGFloat y = self.view.contentOffset.y;
        CGFloat bottomOfAddbutton = -(self.view.addActionArrow.top + 72) + self.view.height + y;
        self.view.top = MIN(bottomOfAddbutton, y);
        self.delegate.navigationBar.top = MIN(self.view.top - self.view.contentOffset.y, 0);
        self.view.contentOffset = CGPointMake(0, y);
        self.view.delegate = self;

        [self.view.addActionButton addTarget:self action:@selector(handleAddButtonTouch:) forControlEvents:UIControlEventTouchUpInside];
        self.actionBrowserVC.view.alpha = 0.0;
        
        if (self.mission.allowsRepeat) {
            self.view.repeatButton.alpha = 1.0;
        }
    }
}

- (void)dismissActionBrowserCompletion
{
    if (_actionBrowserVC.view.superview) {
        [self.view.addActionArrow removeFromSuperview];
        self.view.addActionArrow = nil;

        CGFloat y = self.view.top - self.view.contentOffset.y;
        self.view.top = 0;
        self.view.contentOffset = CGPointMake(0, -y);

        [self.actionBrowserVC.view removeFromSuperview];
        [self.actionBrowserVC removeFromParentViewController];
        self.view.actionBrowserVC = nil;
        self.actionBrowserVC = nil;
    }
}

- (void)updateRepeatButton
{
    UIImage *repeatIcon = self.currentEvent.repeats ? [UIImage imageNamed:@"scriptRepeatButtonOn.png"] : [UIImage imageNamed:@"scriptRepeatButtonOff.png"];
    [self.view.repeatButton setImage:repeatIcon forState:UIControlStateNormal];
    
    NSString *repeatButtonTitle = self.currentEvent.repeats ? NSLocalizedString(@"Script-Repeat-Button-On", @"Repeat") : NSLocalizedString(@"Script-Repeat-Button-Off", @"Repeat Off");
    self.view.repeatButton.titleLabel.minimumScaleFactor = 0.6;
    self.view.repeatButton.titleLabel.numberOfLines = 1;
    self.view.repeatButton.titleLabel.adjustsFontSizeToFitWidth = YES;
    [self.view.repeatButton setTitle:repeatButtonTitle forState:UIControlStateNormal];
    
    UIEdgeInsets titleEdgeInsets = UIEdgeInsetsMake(-32, self.currentEvent.repeats ? -66 : -56, 0, 0);
    self.view.repeatButton.titleEdgeInsets = titleEdgeInsets;
}

#pragma mark - Private Methods

- (void)handleAddButtonTouch:(id)sender
{
    if (!_actionBrowserVC.view.superview) {
        [self presentActionBrowser];
    } else {
        [self dismissActionBrowser];
    }
}

- (void)handleSolveButtonTouch:(UIButton *)solveButton
{
    [RMSoundEffect playForegroundEffectWithName:solveButtonSound repeats:NO gain:1.0];

    if (self.view.showsEvents) {
        self.view.eventsView.delegate = self;
        self.view.eventsView.showsAddEventButton = self.mission.allowsAddingEvents && (self.remainingEvents.count > 0);
        [self.view.eventsView.addEventButton addTarget:self action:@selector(handleAddEventButtonTouch:) forControlEvents:UIControlEventTouchUpInside];
    }

    self.currentEvent = self.mission.events[0];
    
    CGFloat topOffset = self.view.contentOffset.y + self.view.height - self.view.briefingWindow.bottom;
    for (RMActionView *actionView in self.view.actionViews) {
        actionView.top += topOffset;
        
        if (self.mission.glowActionViews) {
            actionView.glowing = YES;
        }
    }
    
    self.view.eventsView.top += topOffset;
    self.view.addActionButton.top += topOffset;
    
    if (self.mission.allowsRepeat) {
        self.view.repeatButton.center = CGPointMake(self.view.width / 2.0 + 72, self.view.addActionButton.centerY);
        [self.view.repeatButton addTarget:self action:@selector(handleRepeatButtonTouch:) forControlEvents:UIControlEventTouchUpInside];
        [self.view addSubview:self.view.repeatButton];
        [self updateRepeatButton];
    }

    if (self.mission.skipDebriefing) {
        self.view.briefingWindow.height -= self.view.solveButton.height - 8;
        [self.view.solveButton removeFromSuperview];

        [self toggleAddButton];
        [self toggleSlideToStart];
        
        [self.view layoutDidChange];
    } else {
        [[UIApplication sharedApplication] beginIgnoringInteractionEvents];
        [UIView animateWithDuration:0.35
                         animations:^{
                             self.view.solveButton.alpha = 0.0;
                             self.view.briefingWindow.height -= self.view.solveButton.height - 8;
                             
                             if (self.view.showsEvents) {
                                 self.view.eventsView.alpha = 1.0;
                             }
                             
                             [self toggleAddButton];
                             
                             [self.view layoutDidChange];
                         } completion:^(BOOL finished) {
                             [self.view.solveButton removeFromSuperview];
                             [self toggleSlideToStart];
                             [[UIApplication sharedApplication] endIgnoringInteractionEvents];
                         }];
    }
}

- (void)handleAddEventButtonTouch:(UIButton *)addEventButton
{
    [self presentEventBrowser];
}

- (void)handleRepeatButtonTouch:(UIButton *)repeatButton
{
    if (self.mission.allowsEditingRepeat) {
        BOOL repeats = !self.currentEvent.repeats;
        self.currentEvent.repeats = repeats;
        [self updateRepeatButton];
    } else {
        [UIView animateWithDuration:0.25
                         animations:^{
                             repeatButton.transform = CGAffineTransformMakeScale(1.2, 1.2);
                         } completion:^(BOOL finished) {
                             [UIView animateWithDuration:0.25
                                              animations:^{
                                                  repeatButton.transform = CGAffineTransformMakeScale(0.9, 0.9);
                                              } completion:^(BOOL finished) {
                                                  [UIView animateWithDuration:0.25
                                                                   animations:^{
                                                                       repeatButton.transform = CGAffineTransformIdentity;
                                                                   }];
                                              }];
                         }];
    }
}

@end
