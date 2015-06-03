//
//  RMDebriefingVC.h
//  Romo
//

#import <UIKit/UIKit.h>
#import "RMMission.h"

@class RMUnlockable;
@class RMSpaceScene;

@protocol RMDebriefingVCDelegate;

@interface RMDebriefingVC : UIViewController

@property (nonatomic, weak) id<RMDebriefingVCDelegate> delegate;
@property (nonatomic, readonly) RMMission *mission;

/** The number of seconds the user played this mission */
@property (nonatomic) double playDuration;

- (id)initWithMission:(RMMission *)mission;

@end

@protocol RMDebriefingVCDelegate <NSObject>

- (void)debriefingVCDidSelectContinue:(RMDebriefingVC *)debriefingVC;
- (void)debriefingVCDidSelectReplay:(RMDebriefingVC *)debriefingVC;
- (void)debriefingVCDidSelectTryAgain:(RMDebriefingVC *)debriefingVC;

#ifdef FAST_MISSIONS
- (void)replay;
#endif

@end