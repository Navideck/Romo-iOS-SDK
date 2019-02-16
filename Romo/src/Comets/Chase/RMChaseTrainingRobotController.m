//
//  RMChaseTrainingRobotController.m
//  Romo
//
//  Created by Ray Morgan on 10/3/13.
//  Copyright (c) 2013 Romotive. All rights reserved.
//

#import "RMChaseTrainingRobotController.h"

#import <Romo/RMVision.h>
#import <Romo/RMCharacter.h>

@interface RMChaseTrainingRobotController ()

@property (nonatomic, strong) RMVision *vision;
@property (nonatomic, copy) RMChaseTrainingRobotControllerCompletion completionHandler;

@property (nonatomic, strong) CAShapeLayer *circleLayer;

@end

@implementation RMChaseTrainingRobotController

- (instancetype)initWithVision:(RMVision *)vision completion:(RMChaseTrainingRobotControllerCompletion)completion
{
    self = [super init];
    if (self) {
        _completionHandler = [completion copy];
        _vision = vision;
        
        self.vision.delegate = self;
    }
    return self;
}

- (void)controllerDidBecomeActive
{
    [super controllerDidBecomeActive];
    [self.Romo.voice say:@"Shake something colorful\nin front of me!"];

    double delayInSeconds = 1.5;
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
//        [self.vision activateModuleWithName:RMVisionModule_MotionTriggeredColorTraining];
        
        CAShapeLayer *backgroundCircle = [[CAShapeLayer alloc] init];
        backgroundCircle.path = [UIBezierPath bezierPathWithOvalInRect:CGRectMake(CGRectGetMidX(self.view.frame) - 50, self.view.frame.size.height - 130, 100, 100)].CGPath;
        backgroundCircle.fillColor = [UIColor whiteColor].CGColor;
        
        self.circleLayer = [[CAShapeLayer alloc] init];
        self.circleLayer.path = [UIBezierPath bezierPathWithOvalInRect:CGRectMake(CGRectGetMidX(self.view.frame) - 50 + 45, self.view.frame.size.height - 125 + 45, 10, 10)].CGPath;
        self.circleLayer.fillColor = [UIColor blackColor].CGColor;
//        self.circleLayer.duration = 1.0;
        
        [self.view.layer addSublayer:backgroundCircle];
        [self.view.layer addSublayer:self.circleLayer];
    });
}

#pragma mark - RMVisionDelegate

- (void)vision:(RMVision *)vision motionTriggeredTrainingDidFinishWithColor:(UIColor *)color withTrainingData:(RMVisionTrainingData *)trainingData
{
//    [self.vision deactivateModuleWithName:RMVisionModule_MotionTriggeredColorTraining];

    self.vision.delegate = nil;
    self.completionHandler(nil, color, trainingData);
}

- (void)vision:(RMVision *)vision motionTriggeredTrainingDidUpdateWithProgress:(float)progress withEstimatedColor:(UIColor *)color
{
    self.circleLayer.path = [UIBezierPath bezierPathWithOvalInRect:CGRectMake(CGRectGetMidX(self.view.frame) - (10.0 + (90.0 * progress)) / 2.0,
                                                                              self.view.frame.size.height - (10.0 + (90.0 * progress)) / 2.0 - 80,
                                                                              10.0 + (90.0 * progress),
                                                                              10.0 + (90.0 * progress))].CGPath;
    self.circleLayer.fillColor = color.CGColor;
}

@end
