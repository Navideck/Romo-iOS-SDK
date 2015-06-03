//
//  RMCharacterAnimation.h
//

#import "RMCharacter.h"
#import "RMCharacterImage.h"

typedef enum {
    RMAnimatedActionIntro,
    RMAnimatedActionExpression,
    RMAnimatedActionIdleEmotion,
    RMAnimatedActionBlink,
    RMAnimatedActionOutro,
} RMAnimatedAction;

@protocol RMCharacterAnimationDelegate;

@interface RMCharacterAnimation : UIImageView

@property (nonatomic, weak)     id<RMCharacterAnimationDelegate> delegate;
@property (nonatomic, readonly) BOOL animating;
@property (nonatomic)           int breakpointFrame;

- (void)animateWithAction:(RMAnimatedAction)action forEmotion:(RMCharacterEmotion)emotion completion:(void (^)(BOOL finished))completion;
- (void)animateWithAction:(RMAnimatedAction)action forExpression:(RMCharacterExpression)expression completion:(void (^)(BOOL finished))completion;
- (void)didReceiveMemoryWarning;

@end

@protocol RMCharacterAnimationDelegate <NSObject>

- (void)animationDidStart;
- (void)animationReachedBreakpointAtFrame:(int)frame;

@end
