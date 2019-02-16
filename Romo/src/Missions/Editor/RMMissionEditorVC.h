//
//  RMMissionEditorVC.h
//  Romo
//

#import <UIKit/UIKit.h>
#import <Romo/RMCore.h>

@class RMMission;
@class RMSpaceScene;
@class RMSlideToStart;

@protocol RMMissionEditorVCDelegate;

@interface RMMissionEditorVC : UIViewController

@property (nonatomic, weak) id<RMMissionEditorVCDelegate> delegate;
@property (nonatomic, strong) RMMission *mission;

@end

@protocol RMMissionEditorVCDelegate <NSObject>

- (void)handleMissionEditorDidStart:(RMMissionEditorVC *)missionEditorVC;
- (UIView *)navigationBar;

@end
