//
//  RMCore.m
//  RMCore
//

#import "RMCore.h"
#import "RMCoreRobot_Internal.h"
#import "RMCoreRobotDataTransport.h"
#import <QuartzCore/QuartzCore.h>
#import <UIKit/UIKit.h>
#import <RMShared/RMMath.h>

#ifdef DEBUG_CONNECTION
//#define CONNECT_LOG(...) NSLog(__VA_ARGS__)
#define CONNECT_LOG(...) NSLog(@"%s self: %@", __PRETTY_FUNCTION__, self)
#else
#define CONNECT_LOG(...)
#endif //DEBUG_CONNECTION

NSString *const RMCoreRobotDidConnectNotification = @"RMCoreRobotDidConnectNotification";
NSString *const RMCoreRobotDidDisconnectNotification = @"RMCoreRobotDidDisconnectNotification";

static RMCore *instance;

@interface RMCore () <RMCoreRobotConnectionDelegate>

@property (nonatomic, weak) id<RMCoreDelegate> delegate;
@property (nonatomic, strong) NSMutableArray *connectedRobots;
@property (nonatomic, strong) RMCoreRobotDataTransport *transport;

void handleSigPipe();

@end

@implementation RMCore

#pragma mark - Init Methods

- (id)initWithDelegate:(id<RMCoreDelegate>)delegate
{
    self = [super init];
    if (self) {
        signal(SIGPIPE, handleSigPipe);
        
        _delegate = delegate;
        _transport = [[RMCoreRobotDataTransport alloc] initWithDelegate:self];
        _connectedRobots = [NSMutableArray arrayWithCapacity:1];
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Public Methods

+ (void)setDelegate:(id<RMCoreDelegate>)delegate
{
    if (!instance) {
        instance = [[RMCore alloc] initWithDelegate:delegate];
    } else {
        instance.delegate = delegate;
    }
}

+ (id<RMCoreDelegate>)delegate
{
    return instance.delegate;
}

+ (void)connectToSimulatedRobot
{
    [instance robotDidConnect:@"SimulatedRomo"];
}

+ (void)disconnectFromSimulatedRobot
{
    [instance robotDidDisconnect:instance.transport];
    [instance.connectedRobots removeAllObjects];
}

#pragma mark - Public Methods

+ (NSArray *)connectedRobots
{
    return [NSArray arrayWithArray:instance.connectedRobots];
}

#pragma mark - RMCoreRobotCommunicationDelegate Methods

- (void)robotDidConnect:(NSString *)name
{
    RMCoreRobot *robot = nil;
    if ([name isEqualToString:@"Romo"]) {
        robot = [[RMCoreRobotRomo3 alloc] initWithTransport:self.transport];
        robot.simulated = NO;
    } else if ([name isEqualToString:@"SimulatedRomo"]) {
        robot = [[RMCoreRobotRomo3 alloc] initWithTransport:nil];
        robot.simulated = YES;
    }
    
    if (robot) {
        CONNECT_LOG(@"self %@", self);
        [robot stopAllMotion];
        [self.connectedRobots addObject:robot];
        [self.delegate robotDidConnect:robot];
        [[NSNotificationCenter defaultCenter] postNotificationName:RMCoreRobotDidConnectNotification
                                                            object:robot];
    }
}

- (void)robotDidDisconnect:(RMCoreRobotDataTransport *)transport
{
    RMCoreRobot *disconnectedRobot = nil;
    for (RMCoreRobot *robot in self.connectedRobots) {
        if (robot.communication.transport == transport) {
            disconnectedRobot = robot;
        }
    }
    
    if (disconnectedRobot) {
        CONNECT_LOG(@"self %@", self);
        disconnectedRobot.communication = nil;
        [self.connectedRobots removeObject:disconnectedRobot];
        
        [self.delegate robotDidDisconnect:disconnectedRobot];
        [[NSNotificationCenter defaultCenter] postNotificationName:RMCoreRobotDidDisconnectNotification
                                                            object:disconnectedRobot];
    }
}

#pragma mark - Private Methods

void handleSigPipe()
{
    // do nothing
}

@end
