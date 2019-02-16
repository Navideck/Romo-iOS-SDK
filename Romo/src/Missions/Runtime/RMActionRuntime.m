//
//  RMActionRuntime.m
//  Romo
//

#import "RMActionRuntime.h"
#import <Romo/RMCore.h>
#import "RMAction.h"
#import "RMParameter.h"
#import "RMActionRunner.h"
#import "RMExploreBehavior.h"

@interface RMActionRuntime () <RMActionRunnerDelegate>

@property (nonatomic, strong) RMActionRunner *runner;

@property (nonatomic, readwrite) BOOL readyToRun;

@property (nonatomic) BOOL wasExploring;

@end

@implementation RMActionRuntime

#pragma mark - Class Methods

+ (NSArray *)allActions
{
    return [RMActionRunner actions];
}

#pragma mark - Public Methods

- (RMActionRuntime *)init
{
    self = [super init];
    if (self) {
        _readyToRun = YES;
    }
    return self;
}

- (void)dealloc
{
    [self.runner.exploreBehavior stopExploring];
}

- (void)runAction:(RMAction *)action
{
    if (self.readyToRun) {
        _readyToRun = NO;
        
        self.runner.runningAction = action;
        
        self.wasExploring = self.wasExploring || self.runner.exploreBehavior.isExploring;
        [self.runner.exploreBehavior stopExploring];
        
        SEL selector = NSSelectorFromString(action.selector);
        
        NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:[RMActionRunner instanceMethodSignatureForSelector:selector]];
        invocation.target = self.runner;
        invocation.selector = selector;
        
        [action.parameters enumerateObjectsUsingBlock:^(RMParameter *parameter, NSUInteger index, BOOL *stop) {
            id value = parameter.value;
            [invocation setArgument:&value atIndex:index + 2];
        }];
        
        [invocation invoke];
    }
}

- (void)stopAllActions
{
    [self.runner stopExecution];
    self.readyToRun = YES;
}

#pragma mark - Public Properties

- (void)setRomo:(RMRomo *)Romo
{
    _Romo = Romo;
    self.runner.Romo = Romo;
}

- (void)setVision:(RMVision *)vision
{
    _vision = vision;
    self.runner.vision = vision;
}

- (void)setStasisVirtualSensor:(RMStasisVirtualSensor *)stasisVirtualSensor
{
    _stasisVirtualSensor = stasisVirtualSensor;
    self.runner.exploreBehavior.stasisVirtualSensor = stasisVirtualSensor;
}

#pragma mark - RMActionRunnerDelegate

- (void)runnerBecameReadyToContinueExecution:(RMActionRunner *)runner
{
    if (self.wasExploring) {
        self.wasExploring = NO;
        [self.runner.exploreBehavior startExploring];
    }
    
    self.readyToRun = YES;
    [self.delegate actionRuntime:self finishedRunningAction:self.runner.runningAction];
}

#pragma mark - Private Properties

- (RMActionRunner *)runner
{
    if (!_runner) {
        _runner = [[RMActionRunner alloc] init];
        _runner.delegate = self;
    }
    return _runner;
}

#pragma mark - Private Methods

- (void)setReadyToRun:(BOOL)readyToRun
{
    if (readyToRun != _readyToRun) {
        _readyToRun = readyToRun;

        if (readyToRun) {
            [self.delegate actionRuntimeBecameReadyToRunNextAction:self];
        }
    }
}

@end
