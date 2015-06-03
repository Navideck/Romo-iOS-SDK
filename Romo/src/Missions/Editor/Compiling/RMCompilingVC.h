//
//  RMCompilingVC.h
//  Romo
//

#import <UIKit/UIKit.h>

@class RMMission;
@class RMSpaceScene;

@protocol RMCompilingVCDelegate;

@interface RMCompilingVC : UIViewController

@property (nonatomic, weak) id<RMCompilingVCDelegate> delegate;

/** The mission that is being compiled */
@property (nonatomic, strong) RMMission *mission;

/** "Compiles" and animates the progress */
- (void)compile;

@end

@protocol RMCompilingVCDelegate <NSObject>

- (void)compilingVCDidFinishCompiling:(RMCompilingVC *)compilingVC;
- (void)compilingVCDidFailToCompile:(RMCompilingVC *)compilingVC;

@end