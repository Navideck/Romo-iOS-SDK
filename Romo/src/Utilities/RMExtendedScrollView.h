//
//  RMExtendedScrollView.h
//  Romo
//

#import <UIKit/UIKit.h>

/**
 Allows for a paginated scroll view's touches to extend beyond the bounds
 */
@interface RMExtendedScrollView : UIView

@property (nonatomic, strong) UIScrollView *extendedScrollView;
@property (nonatomic) BOOL extendsHorizontally;
@property (nonatomic) BOOL extendsVertically;

@end
