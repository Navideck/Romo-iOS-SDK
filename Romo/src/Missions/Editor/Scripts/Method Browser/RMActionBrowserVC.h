//
//  RMActionBrowser.h
//  Romo
//

#import <UIKit/UIKit.h>

@class RMAction;
@class RMActionIcon;

@protocol RMActionBrowserDelegate;

@interface RMActionBrowserVC : UIViewController

@property (nonatomic, weak) id<RMActionBrowserDelegate> delegate;

/** 
 If nil, all actions will be shown
 Otherwise only these actions will be available
 */
@property (nonatomic, strong) NSArray *availableActions;

@end

@protocol RMActionBrowserDelegate <NSObject>

- (void)actionBrowser:(RMActionBrowserVC *)browser didSelectIcon:(RMActionIcon *)icon withAction:(RMAction *)action;

@end
