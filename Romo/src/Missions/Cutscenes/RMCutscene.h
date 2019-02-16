//
//  RMCutscene.h
//  Romo
//

#import <Foundation/Foundation.h>
#import <Romo/RMCore.h>

@class RMCoreRobot;
@protocol LEDProtocol;

@protocol RMCutsceneDelegate;

@interface RMCutscene : NSObject

@property (nonatomic, weak) id<RMCutsceneDelegate> delegate;
@property (nonatomic, readonly) UIView *view;
@property (nonatomic, weak) RMCoreRobotRomo3 *robot;

- (void)playCutscene:(int)cutscene inView:(UIView *)view completion:(void (^)(BOOL finished))completion;

@end

@protocol RMCutsceneDelegate <NSObject>

- (void)cutsceneDidFinishPlaying:(RMCutscene *)cutscene;

@end
