//
//  RMCharacterUnlockedVC.h
//  Romo
//

#import <UIKit/UIKit.h>
#import "RMRobotController.h"
#import <Romo/RMCharacter.h>

@protocol RMCharacterUnlockedDelegate;

@interface RMCharacterUnlockedRobotController : RMRobotController

@property (nonatomic, weak) id<RMCharacterUnlockedDelegate> delegate;

- (id)initWithExpression:(RMCharacterExpression)expression;

@property (nonatomic) float autoDismissInterval;

@end

@protocol RMCharacterUnlockedDelegate <NSObject>

- (void)dismissCharacterUnlockedVC:(RMCharacterUnlockedRobotController *)unlockedVC;

@end
