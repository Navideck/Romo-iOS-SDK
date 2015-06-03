//
//  RMSpriteView.h
//  TestSprite
//

#import <UIKit/UIKit.h>

@interface RMSpriteView : UIView

/**
 The name of the sprite. This is used to find both the image and JSON meta data files on disk
 */
@property (nonatomic, readonly) NSString *spriteName;

/**
 How many times this animation is repeated. To infinitely loop use the HUGE_VAL constant
 */
@property (nonatomic, readonly) NSUInteger repeatCount;

/**
 If the animation reverses or not
 */
@property (nonatomic, readonly) BOOL autoreverses;

/**
 Determines how many sprite frames to show a second
 */
@property (nonatomic, readonly) CGFloat framesPerSecond;

/**
 Instantiates the sprite with a name, repeatCount and framesPerSecond. These properties are readonly
 after the RMSpriteView is created.
 
 Setting repeatCount to HUGE_VALF causes it to repeat infinitely
 */
- (instancetype)initWithFrame:(CGRect)frame
                   spriteName:(NSString *)spriteName
                  repeatCount:(NSUInteger)repeatCount
                 autoreverses:(BOOL)autoreverses
              framesPerSecond:(CGFloat)framesPerSecond;

/**
 startAnimating and stopAnimating are automatically called when the view is added or removed from
 a window.
 
 You can manually call these to stop or start the animation yourself. Note that when a sprite is
 not animating, currently it is completely hidden.
 */
- (void)startAnimating;
- (void)stopAnimating;

@end
