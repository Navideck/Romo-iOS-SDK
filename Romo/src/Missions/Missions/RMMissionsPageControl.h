//
//  RMMissionsPageControl.h
//  Romo
//

#import <UIKit/UIKit.h>

@protocol RMMissionsPageControlDelegate;

@interface RMMissionsPageControl : UIPageControl

@property (nonatomic, weak) id<RMMissionsPageControlDelegate> delegate;

@end

@protocol RMMissionsPageControlDelegate <NSObject>

- (void)pageControl:(RMMissionsPageControl *)pageControl didSelectPage:(int)page;

@end
