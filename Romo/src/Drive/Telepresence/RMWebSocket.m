//
//  RMWebSocket.m
//  Romo3
//
//  Created by Ray Morgan on 5/1/13.
//  Copyright (c) 2013 Romotive. All rights reserved.
//

#import "RMWebSocket.h"
#import "SRWebSocket.h"
#import "AFNetworking.h"

/**
 * The values of the following enum are important. They match up directly with
 * Socket.io's message command numbers.
 */
typedef enum RMWebSocketSocketIOCommand {
    RMWebSocketSocketIOCommandDisconnect = 0,
    RMWebSocketSocketIOCommandConnect = 1,
    RMWebSocketSocketIOCommandHeartbeat = 2,
    RMWebSocketSocketIOCommandMessage = 3,
    RMWebSocketSocketIOCommandJSONMessage = 4,
    RMWebSocketSocketIOCommandEvent = 5,
    RMWebSocketSocketIOCommandAck = 6,
    RMWebSocketSocketIOCommandError = 7,
    RMWebSocketSocketIOCommandNoop = 8
} RMWebSocketSocketIOCommand;


@interface RMWebSocketMessage : NSObject

@property (nonatomic, assign) RMWebSocketSocketIOCommand command;
@property (nonatomic, assign) NSInteger sequence;
@property (nonatomic, assign) BOOL userAck;
@property (nonatomic, strong) NSString *namespace;
@property (nonatomic, strong) NSString *data;
@property (nonatomic, assign) NSInteger ackNumber;

- (id)initWithMatches:(NSArray *)matches;

@end


@interface RMWebSocket () <SRWebSocketDelegate>

@property (nonatomic, readwrite, strong) NSString *name;

@property (nonatomic, strong) SRWebSocket *socket;
@property (nonatomic, strong) NSString *host;
@property (nonatomic, strong) NSMutableDictionary *eventHandlers;
@property (nonatomic, strong) NSMutableDictionary *ackHandlers;
@property (nonatomic, assign) NSInteger sequence;

@property (nonatomic, strong) NSURL *serverURL;

@end

@implementation RMWebSocket

DDLOG_ENABLE_DYNAMIC_LEVELS

#pragma mark - Object Lifecycle

- (id)initWithName:(NSString *)name host:(NSString *)host delegate:(id <RMWebSocketDelegate>)delegate
{
    self = [self init];
    
    if (self) {
        _name = name;
        _host = host;
        _delegate = delegate;
        
        _eventHandlers = [NSMutableDictionary dictionary];
        _ackHandlers = [NSMutableDictionary dictionary];
        _state = RMWebSocketStateConnecting;
        _sequence = 1;
        
        [self openConnection];
    }
    
    return self;
}

- (void)dealloc
{
    [self.socket close];
    self.socket.delegate = nil;
}


#pragma mark - Opening Web Socket Connection

- (NSURL *)serverURL
{
    if (!_serverURL) {
        // On 3G, WebSockets are denied on port 80 sometimes, so we use an
        // alternate port (8000) instead.
        NSInteger alternatePort = 8000;

        NSString *regexPattern = [NSString stringWithFormat:@":([0-9]{2,}+)"];
        NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:regexPattern
                                                                               options:NSRegularExpressionCaseInsensitive
                                                                                 error:nil];
        NSUInteger numberOfMatches = [regex numberOfMatchesInString:self.host
                                                            options:0
                                                              range:NSMakeRange(0, [self.host length])];

        // If the host is already targeting some port, leave it be.
        // Else, have it target the alternate port.
        NSString *host = (numberOfMatches == 1) ? self.host : [NSString stringWithFormat:@"%@:%d", self.host, alternatePort];
        _serverURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@/socket.io/1", host]];
    }

    return _serverURL;
}

- (void)openConnection
{    
    NSTimeInterval time = [[NSDate date] timeIntervalSince1970] * 1000;
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"http://%@?t=%.0f", [self serverURL], time]];
    
    AFHTTPRequestOperation *operation = [[AFHTTPRequestOperation alloc] initWithRequest:[NSURLRequest requestWithURL:url]];
    
    [operation setCompletionBlockWithSuccess:^(AFHTTPRequestOperation *operation, id responseObject) {
        NSString *token = [self webSocketHandshakeTokenFromData:responseObject];
        [self openWebSocketConnectionWithToken:token];
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        if ([self.delegate respondsToSelector:@selector(webSocket:didReceiveError:)]) {
            [self.delegate webSocket:self didReceiveError:error];
        }
        
        self.state = RMWebSocketStateDisconnected;
    }];
    
    [operation start];
}

- (void)openWebSocketConnectionWithToken:(NSString *)token
{
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"ws://%@/websocket/%@", [self serverURL], token]];
    
    self.socket = [[SRWebSocket alloc] initWithURL:url];
    self.socket.delegate = self;
    [self.socket open];
}

- (NSString *)webSocketHandshakeTokenFromData:(NSData *)data
{
    NSString *stringData = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    return [stringData componentsSeparatedByString:@":"][0];
}


#pragma mark - Sending Events

- (void)sendEvent:(NSString *)event withData:(id)data
{
    [self sendEvent:event withData:data completion:nil];
}

- (void)sendEvent:(NSString *)event withData:(id)data completion:(RMWebSocketAckBlock)ackBlock
{
    if (data) {
        data = @{@"name": event, @"args": @[data]};
    } else {
        data = @{@"name": event, @"args": @[]};
    }
    
    NSData *JSONData = [NSJSONSerialization dataWithJSONObject:data options:0 error:nil];
    NSString *json = [[NSString alloc] initWithData:JSONData encoding:NSUTF8StringEncoding];
    NSString *message = nil;

    if (ackBlock) {
        NSInteger sequence = self.sequence++;
        self.ackHandlers[@(sequence)] = [ackBlock copy];
        message = [self messageWithCommand:RMWebSocketSocketIOCommandEvent ack:sequence userHandledAck:YES endpoint:@"" data:json];
    } else {
        message = [self messageWithCommand:RMWebSocketSocketIOCommandEvent ack:0 userHandledAck:NO endpoint:@"" data:json];
    }
    
//    DDLogVerbose(@"Sending message: %@", message);

    if (self.socket.readyState == SR_OPEN) {
        [self.socket send:message];
    }
}

- (void)sendCommand:(NSString *)name withData:(id)data
{
    [self sendCommand:name withData:data completion:nil];
}

- (void)sendCommand:(NSString *)name withData:(id)data completion:(RMWebSocketAckBlock)ackBlock
{
    if (data == nil) {
        data = @{@"name": name};
    } else {
        data = @{@"name": name, @"data": data};
    }
    
    [self sendEvent:@"session/command" withData:data completion:ackBlock];
}


#pragma mark - Event Handling

- (void)addTarget:(id)target action:(SEL)action forEvent:(NSString *)name
{
    NSMethodSignature *methodSignature = [target methodSignatureForSelector:action];
    NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:methodSignature];
    
    invocation.target = target;
    invocation.selector = action;
    
    if (self.eventHandlers[name]) {
        [self.eventHandlers[name] addObject:invocation];
    } else {
        self.eventHandlers[name] = [NSMutableArray arrayWithObject:invocation];
    }
}

- (void)removeHandlersForTarget:(id)target
{
    [self.eventHandlers enumerateKeysAndObjectsUsingBlock:^(NSString *eventName, NSMutableArray *handlers, BOOL *stop) {
        NSIndexSet *deletionSet = [handlers indexesOfObjectsPassingTest:^BOOL(NSInvocation *invocation, NSUInteger idx, BOOL *stop) {
            return invocation.target == target;
        }];
        
        [handlers removeObjectsAtIndexes:deletionSet];
    }];
}

- (void)removeHandlersForEvent:(NSString *)name
{
    [self.eventHandlers removeObjectForKey:name];
}

- (void)removeAllHandlers
{
    [self.eventHandlers removeAllObjects];
}

- (void)dispatchEvent:(NSString *)name data:(id)data
{
    NSArray *handlers = self.eventHandlers[name];
    
    if (handlers) {
        [handlers enumerateObjectsUsingBlock:^(NSInvocation *invocation, NSUInteger idx, BOOL *stop) {
            // Check to see if this method signature takes a "data" argument, if so,
            // let's add the argument to the invocation.
            if (invocation.methodSignature.numberOfArguments == 3) {
                id argument = data;
                [invocation setArgument:&argument atIndex:2];
            }
            
            [invocation invoke];
        }];
    } else {
        DDLogVerbose(@"(%@) Unhandled event: %@", self.name, name);
    }
}


#pragma mark - Encoding and Decoding Socket.io Messages

- (NSString *)messageWithCommand:(RMWebSocketSocketIOCommand)command
                             ack:(NSInteger)ack
                  userHandledAck:(BOOL)userHandledAck
                        endpoint:(NSString *)endpoint
                            data:(NSString *)data
{
    NSMutableString *message = [NSMutableString stringWithFormat:@"%i:", command];
    
    if (ack > 0) {
        [message appendFormat:@"%i%@", ack, userHandledAck ? @"+" : @""];
    }
    
    [message appendString:@":"];
    
    if (endpoint) {
        [message appendString:endpoint];
    }
    
    if (data) {
        [message appendFormat:@":%@", data];
    }
    
    return message;
}

- (RMWebSocketMessage *)decodeMessage:(NSString *)message
{
    static NSString *pattern = @"^([^:]+):([0-9]+)?(\\+)?:([^:]+)?:?(.*)?$";
    static NSRegularExpression *regexp = nil;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        regexp = [NSRegularExpression regularExpressionWithPattern:pattern options:0 error:nil];
    });
    
    NSMutableArray *matches = [NSMutableArray array];
    __block int index = -1;
    
    [regexp
     enumerateMatchesInString:message
     options:0
     range:NSMakeRange(0, message.length)
     usingBlock:^(NSTextCheckingResult *result, NSMatchingFlags flags, BOOL *stop) {
         for (int i = 0; i < result.numberOfRanges; i++) {
             NSRange range = [result rangeAtIndex:i];
             
             if (index++ >= 0) {
                 if (range.location == NSNotFound) {
                     [matches addObject:[NSNull null]];
                 } else {
                     [matches addObject:[message substringWithRange:range]];
                 }
             }
         }
     }];
    
    RMWebSocketMessage *socketMessage = [[RMWebSocketMessage alloc] initWithMatches:matches];
    
    return socketMessage;
}


#pragma mark - SRWebSocketDelegate

- (void)webSocket:(SRWebSocket *)webSocket didReceiveMessage:(id)message
{
    RMWebSocketMessage *socketMessage = [self decodeMessage:message];
    id JSONData = nil;
    RMWebSocketAckBlock ackBlock;
    
    switch (socketMessage.command) {
        case RMWebSocketSocketIOCommandConnect:
            [self dispatchEvent:@"connect" data:nil];
            break;
            
        case RMWebSocketSocketIOCommandDisconnect:
            [self dispatchEvent:@"disconnect" data:nil];
            break;
            
        case RMWebSocketSocketIOCommandHeartbeat:
            break;
            
        case RMWebSocketSocketIOCommandMessage:
            [self dispatchEvent:@"message" data:socketMessage.data];
            break;
            
        case RMWebSocketSocketIOCommandJSONMessage:
            JSONData = [NSJSONSerialization JSONObjectWithData:[socketMessage.data dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil];
            [self dispatchEvent:@"JSONMessage" data:JSONData];
            break;
            
        case RMWebSocketSocketIOCommandEvent:
            JSONData = [NSJSONSerialization JSONObjectWithData:[socketMessage.data dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil];
            [self dispatchEvent:JSONData[@"name"] data:JSONData[@"args"][0]];
            break;
            
        case RMWebSocketSocketIOCommandAck:
            ackBlock = self.ackHandlers[@(socketMessage.ackNumber)];
            
            if (ackBlock) {
                JSONData = [NSJSONSerialization JSONObjectWithData:[socketMessage.data dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil];
                ackBlock(JSONData[0]);
                [self.ackHandlers removeObjectForKey:@(socketMessage.ackNumber)];
            }
            
            break;
            
        case RMWebSocketSocketIOCommandError:
            break;
            
        case RMWebSocketSocketIOCommandNoop:
            break;
    }
}

- (void)webSocketDidOpen:(SRWebSocket *)webSocket
{
    self.state = RMWebSocketStateConnected;
}

- (void)webSocket:(SRWebSocket *)webSocket didFailWithError:(NSError *)error
{
    self.state = RMWebSocketStateDisconnected;
    
    if ([self.delegate respondsToSelector:@selector(webSocket:didReceiveError:)]) {
        [self.delegate webSocket:self didReceiveError:error];
    }
}

- (void)webSocket:(SRWebSocket *)webSocket didCloseWithCode:(NSInteger)code reason:(NSString *)reason wasClean:(BOOL)wasClean
{
    self.state = RMWebSocketStateDisconnected;
    
    if (wasClean == NO && [self.delegate respondsToSelector:@selector(webSocket:didDisconnectWithError:)]) {
        NSError *error = [NSError errorWithDomain:@"com.romotive.websocket" code:code userInfo:@{NSLocalizedDescriptionKey: reason}];
        [self.delegate webSocket:self didDisconnectWithError:error];
    }
}

@end


@implementation RMWebSocketMessage

- (id)initWithMatches:(NSArray *)matches
{
    self = [self init];
    
    if (self) {
        _ackNumber = -1;
        
        if (matches[0] != [NSNull null]) {
            self.command = [matches[0] integerValue];
        }
        
        if (matches[1] != [NSNull null]) {
            self.sequence = [matches[1] integerValue];
        }
        
        if (matches[2] != [NSNull null]) {
            self.userAck = [matches[2] isEqualToString:@"+"];
        }
        
        if (matches[3] != [NSNull null]) {
            self.namespace = matches[3];
        } else {
            self.namespace = @"/";
        }
        
        if (matches[4] != [NSNull null]) {
            if (self.command == RMWebSocketSocketIOCommandAck) {
                [self decodeAckData:matches[4]];
            } else {
                self.data = matches[4];
            }
        }
    }
    
    return self;
}

- (void)decodeAckData:(NSString *)data
{
    static NSString *pattern = @"^([0-9]+)(?:\\+(.*))?$";
    static NSRegularExpression *regexp = nil;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        regexp = [NSRegularExpression regularExpressionWithPattern:pattern options:0 error:nil];
    });
    
    
    [regexp
     enumerateMatchesInString:data
     options:0
     range:NSMakeRange(0, data.length)
     usingBlock:^(NSTextCheckingResult *result, NSMatchingFlags flags, BOOL *stop) {
         for (int i = 0; i < result.numberOfRanges; i++) {
             NSRange range = [result rangeAtIndex:i];
             
             if (i-1 >= 0) {
                 NSString *match = nil;
                 
                 if (range.location != NSNotFound) {
                     match = [data substringWithRange:range];
                 }
                 
                 if (i-1 == 0) {
                     self.ackNumber = [match integerValue];
                 } else {
                     self.data = match;
                 }
             }
         }
     }];
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<RMWebSocketMessage command: %i, sequence: %i, userAck: %i, namespace: %@, ackNumber: %i, data: %@",
            self.command, self.sequence, self.userAck, self.namespace, self.ackNumber, self.data];
}

@end
