//
//  RMHTTPLogger.m
//  Romo
//

#import "RMWebSocketLogger.h"
#import "RMWebSocket.h"
#import "UIApplication+Environment.h"
#import "UIDevice+UDID.h"

@interface RMWebSocketLogger () <RMWebSocketDelegate>

@property (nonatomic, strong) RMWebSocket *socket;
@property (nonatomic, strong) NSMutableArray *messageQueue;

@end

@implementation RMWebSocketLogger

DDLOG_ENABLE_DYNAMIC_LEVELS

+ (id)sharedInstance
{
    static RMWebSocketLogger *_sharedLogger = nil;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        _sharedLogger = [[self alloc] init];
    });
    
    return _sharedLogger;
}

#pragma mark - Object Lifecycle

- (id)init
{
    self = [super init];
    
    if (self) {
        NSString *host = [UIApplication environmentVariableWithKey:@"ROMO_LOG_SERVER"];
        [DDLog setLogLevel:LOG_LEVEL_INFO forClassWithName:NSStringFromClass(self.class)];
        if (host) {
            [self reconnectToServerAfterTimeout:0];
        }
        
        _messageQueue = [NSMutableArray array];
    }
    
    return self;
}

- (void)dealloc
{
    [self.socket removeObserver:self forKeyPath:@"state"];
}

#pragma mark - KVO

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (object == self.socket && [keyPath isEqualToString:@"state"]) {
        [self webSocketDidChangeToState:self.socket.state fromState:[change[NSKeyValueChangeOldKey] intValue]];
    }
}

#pragma mark - Logging Messages

- (void)logMessage:(DDLogMessage *)logMessage
{
    if (self.socket.state == RMWebSocketStateConnected) {
        [self sendLogMessage:logMessage];
    } else {
        [self.messageQueue addObject:logMessage];
    }
}

- (void)sendLogMessage:(DDLogMessage *)logMessage
{
    NSString *message = logMessage->logMsg;
    
    [self.socket sendEvent:@"logger/message" withData:@{
     @"message": message,
     @"deviceName": [[UIDevice currentDevice] name],
     @"deviceId": [UIDevice currentDevice].UDID,
     @"date": @([[NSDate date] timeIntervalSince1970]),
     @"fileName": logMessage.fileName,
     @"function": logMessage.methodName,
     @"line": @(logMessage->lineNumber),
     @"appName": @"Romo",
     @"logLeve": @(logMessage->logLevel)
     }];
}

#pragma mark - Connecting to server

- (void)reconnectToServerAfterTimeout:(NSTimeInterval)timeout
{
    double delayInSeconds = timeout;
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
        [self.socket removeObserver:self forKeyPath:@"state"];
        
        self.socket = [[RMWebSocket alloc] initWithName:@"Logger" host:[UIApplication environmentVariableWithKey:@"ROMO_LOG_SERVER"] delegate:self];
        [self.socket addObserver:self forKeyPath:@"state" options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld context:nil];
        
        [self setupEventHandlers];
        
        DDLogVerbose(@"Reconnecting to web socket log server.");
    });
}

#pragma mark - Handling Events

- (void)setupEventHandlers
{
    [self.socket addTarget:self action:@selector(didReceiveLogLevelChangeEvent:) forEvent:@"logger/logLevelChange"];
}

- (void)didReceiveLogLevelChangeEvent:(id)data
{
    NSString *className = data[@"className"];
    NSString *logLevelName = [data[@"logLevel"] lowercaseString];
    
    int logLevel = ddLogLevel;
    
    if ([logLevelName isEqualToString:@"verbose"]) {
        logLevel = LOG_LEVEL_VERBOSE;
    }
    else if ([logLevelName isEqualToString:@"info"]) {
        logLevel = LOG_LEVEL_INFO;
    }
    else if ([logLevelName isEqualToString:@"warn"]) {
        logLevel = LOG_LEVEL_WARN;
    }
    else if ([logLevelName isEqualToString:@"error"]) {
        logLevel = LOG_LEVEL_ERROR;
    }
    
    if ([className isEqualToString:@"all"]) {
        [[DDLog registeredClasses] enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            [DDLog setLogLevel:logLevel forClass:obj];
        }];
    } else {
        [DDLog setLogLevel:logLevel forClassWithName:className];
    }
    
    [self.socket sendEvent:@"logger/didChangeLogLevel" withData:@{
     @"deviceName": [[UIDevice currentDevice] name],
     @"logLevel": logLevelName
     }];
}

#pragma mark - RMWebSocketDelegate

- (void)webSocketDidChangeToState:(RMWebSocketState)state fromState:(RMWebSocketState)oldState
{
    if (state == RMWebSocketStateConnected) {
        [self.messageQueue enumerateObjectsUsingBlock:^(DDLogMessage *message, NSUInteger idx, BOOL *stop) {
            [self sendLogMessage:message];
        }];
        
        [self.messageQueue removeAllObjects];
    }
    else if (state == RMWebSocketStateDisconnected && oldState == RMWebSocketStateConnected) {
        [self reconnectToServerAfterTimeout:5];
    }
}

- (void)webSocket:(RMWebSocket *)socket didReceiveError:(NSError *)error
{
    [self reconnectToServerAfterTimeout:5];
}

@end
