//
//  RomoPopupView.h
//  RomoPopUpView
//

#import <UIKit/UIKit.h>

typedef void(^RMAlertViewCompletion)(void);

@class RMAlertView;

@protocol RMAlertViewDelegate <NSObject>

- (void)alertViewDidDismiss:(RMAlertView *)alertView;

@end

@interface RMAlertView : UIView

@property (nonatomic, weak) id<RMAlertViewDelegate> delegate;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *message;
@property (nonatomic, copy) RMAlertViewCompletion completionHandler;

+ (void)dismissAll;

- (id)initWithTitle:(NSString *)title message:(NSString *)message delegate:(id<RMAlertViewDelegate>)delegate;

- (void)show;
- (void)dismiss;

@end
