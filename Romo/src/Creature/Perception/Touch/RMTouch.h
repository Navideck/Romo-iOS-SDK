//
//  RMTouch.h
//  Poke
//

#import <UIKit/UIKit.h>

typedef enum {
    RMTouchLocationNone     = 0,
    RMTouchLocationForehead = 1,
    RMTouchLocationLeftEye  = 2,
    RMTouchLocationRightEye = 3,
    RMTouchLocationNose     = 4,
    RMTouchLocationChin     = 5,
} RMTouchLocation;

@protocol RMTouchDelegate;

@interface RMTouch : UIView

@property (nonatomic, weak) id<RMTouchDelegate> delegate;

+ (NSString *)nameForLocation:(RMTouchLocation)location;

@end

@protocol RMTouchDelegate <NSObject>

@optional

- (void)touch:(RMTouch *)touch beganPokingAtLocation:(RMTouchLocation)location;
- (void)touch:(RMTouch *)touch endedPokingAtLocation:(RMTouchLocation)location;
- (void)touch:(RMTouch *)touch cancelledPokingAtLocation:(RMTouchLocation)location;
- (void)touch:(RMTouch *)touch detectedTickleAtLocation:(RMTouchLocation)location;

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event;
- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event;
- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event;
- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event;

@end