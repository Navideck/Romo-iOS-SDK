//
//  RMButtonIcon.h
//  Romo
//

#import <UIKit/UIKit.h>

@protocol RMButtonIconDelegate;

@interface RMButtonIcon : UIImageView

@property (nonatomic, weak) id<RMButtonIconDelegate> delegate;

@property (nonatomic, strong) UIView *contentView;

@property (nonatomic, copy) NSString *title;

- (void)layoutForExpansion;

@end

@protocol RMButtonIconDelegate <NSObject>

- (void)didTouchButtonIcon:(RMButtonIcon *)buttonIcon;

@end
