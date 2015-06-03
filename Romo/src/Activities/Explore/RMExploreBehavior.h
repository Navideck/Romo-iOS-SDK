//
//  RMExploreRobotController.h
//  Romo
//

#import <UIKit/UIKit.h>

@class RMRomo;
@class RMStasisVirtualSensor;

@interface RMExploreBehavior : NSObject

@property (nonatomic, strong) RMRomo *Romo;

@property (nonatomic, getter=isExploring, readonly) BOOL exploring;

@property (nonatomic, strong) RMStasisVirtualSensor *stasisVirtualSensor;

- (void)startExploring;
- (void)stopExploring;

@end
