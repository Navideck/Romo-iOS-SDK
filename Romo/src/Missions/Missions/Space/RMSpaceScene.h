#import <UIKit/UIKit.h>
#import <Romo/RMCharacter.h>

@class RMSpaceObject;

@protocol RMSpaceSceneDelegate;

@interface RMSpaceScene : UIView

@property (nonatomic, weak) id<RMSpaceSceneDelegate> delegate;

/**
 The current vantage point
 -setCameraLocation: does not smoothly animate the transition; instead use -setCameraLocation:animated:
 */
@property (nonatomic) RMPoint3D cameraLocation;

/** 
 All space objects in the Universe
 */
@property (nonatomic, readonly) NSArray *spaceObjects;

/** Is an animation running? */
@property (nonatomic, getter=isAnimating, readonly) BOOL animating;

/** Animates the position change with the specified duration then calls completion */
- (void)setCameraLocation:(RMPoint3D)cameraLocation animatedWithDuration:(float)duration completion:(void (^)(void))completion;

/** Populating the Universe */
- (void)addSpaceObject:(RMSpaceObject *)spaceObject;
- (void)addSpaceObjects:(NSArray *)spaceObjects;
- (void)removeSpaceObject:(RMSpaceObject *)spaceObject;
- (void)removeSpaceObjects:(NSArray *)spaceObjects;

@end

@protocol RMSpaceSceneDelegate <NSObject>

- (void)spaceScene:(RMSpaceScene *)spaceScene didAnimateCameraLocation:(RMPoint3D)cameraLocation withRatio:(float)ratio;

@end
