//
//  RMMissionEditorView.h
//  Romo
//

#import <UIKit/UIKit.h>
#import "RMEventsView.h"
#import "RMActionView.h"
#import "RMSlideToStart.h"

@class RMMission;
@class RMEvent;
@class RMEventIcon;
@class RMAction;
@class RMParameter;
@class RMActionBrowserVC;

@interface RMMissionEditorView : UIScrollView

#define topYGap 12

@property (nonatomic, weak) id<RMActionViewDelegate> actionViewDelegate;

@property (nonatomic, strong) RMMission *mission;

/** The script model being represented */
@property (nonatomic, strong) NSArray *script;

/** If the mission allows adding events or has an event other than on-start */
@property (nonatomic) BOOL showsEvents;

/** The bubbles for all events */
@property (nonatomic, readonly) RMEventsView *eventsView;

/** Ordered list of action views for the script */
@property (nonatomic, strong) NSMutableArray *actionViews;

/** Reveals a library navigator for adding actions */
@property (nonatomic, strong) UIButton *addActionButton;

/** A blue chevron showing where the action is being inserted; shown when -layoutForAdding: is YES */
@property (nonatomic, strong) UIView *addActionArrow;

/** When a action browser is shown, expand our content size to show it */
@property (nonatomic, strong) RMActionBrowserVC *actionBrowserVC;

/** A briefing view to be shown at the top */
@property (nonatomic, readonly) UIImageView *briefingWindow;

/** A button in the briefing window */
@property (nonatomic, readonly) UIButton *solveButton;

/** A slider that starts the mission */
@property (nonatomic, readonly) RMSlideToStart *slideToStart;

/** A button that toggles on or off repeat */
@property (nonatomic, strong) UIButton *repeatButton;

/** Adds an action to the end of the current script and a actionView to the screen */
- (RMActionView *)addAction:(RMAction *)action;

/** Inserts an action at the provided index into the current script */
- (RMActionView *)insertAction:(RMAction *)action atIndex:(NSInteger)index;

- (void)actionView:(RMActionView *)actionView didDragByOffset:(CGPoint)offset fromOrigin:(CGPoint)origin;
- (int)actionView:(RMActionView *)actionView didEndDragging:(CGPoint)offset fromOrigin:(CGPoint)origin;

- (void)layoutDidChange;

@end
