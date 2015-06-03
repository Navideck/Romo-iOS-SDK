//
//  RMSlideToRun.h
//  Romo
//

#import <UIKit/UIKit.h>

@protocol RMSlideToStartDelegate;

static const CGFloat slideToStartPadding = 16.0;

@interface RMSlideToStart : UIScrollView

@property (nonatomic, weak) id<RMSlideToStartDelegate> slideDelegate;

@end

@protocol RMSlideToStartDelegate <NSObject>

- (void)slideToStart:(RMSlideToStart *)slideToStart;

@end