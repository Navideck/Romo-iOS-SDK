//
//  RMTiltController.h
//

//

@protocol RMTiltControllerDelegate;

@interface RMTiltController : UIView

@property (nonatomic, weak) id<RMTiltControllerDelegate>delegate;
@property (nonatomic) BOOL showHint;

@end

@protocol RMTiltControllerDelegate <NSObject>

- (void)tiltWithVelocity:(CGFloat)velocity;

@end 