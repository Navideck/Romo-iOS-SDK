//
//  RMEventBrowserView.h
//  Romo
//

#import <UIKit/UIKit.h>

@interface RMEventBrowserView : UIView

/** The bordered view that contains all events */
@property (nonatomic, strong, readonly) UIImageView *window;

@property (nonatomic, strong, readonly) UILabel *titleLabel;

@property (nonatomic, strong, readonly) UIButton *dismissButton;

@property (nonatomic, strong, readonly) UIScrollView *scrollView;

@property (nonatomic, strong) NSArray *eventIcons;

- (void)layoutForEventIconOptions:(NSArray *)eventIconOptions;

@end
