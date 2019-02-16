//
//  RMTelepresence2Presence.m
//  Romo
//
//  Created on 11/5/13.
//  Copyright (c) 2013 Romotive. All rights reserved.
//

#import "RMTelepresencePresence.h"
#import "RMAppDelegate.h"
#import "RMTelepresenceIncomingCallVC.h"
#import "RMTelepresenceHostRobotController.h"
#import "RMAnalytics.h"
#import <Romo/UIDevice+UDID.h>
#import <SocketRocket/SRWebSocket.h>
#import <Romo/UIApplication+Environment.h>

static const int kAutoAnswerCallBackWithin = 120;

@interface RMTelepresencePresence () <SRWebSocketDelegate>

@property (nonatomic, strong) SRWebSocket *socket;
@property (nonatomic, assign, getter = isInCall) BOOL inCall;
@property (nonatomic, strong, readwrite) NSString *number;
@property (nonatomic, strong) NSString *previousCallUUID;

@property (nonatomic, strong) RMTelepresenceHostRobotController *hostController;

@end

@implementation RMTelepresencePresence

+ (instancetype)sharedInstance
{
    static RMTelepresencePresence *presence = nil;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        presence = [[RMTelepresencePresence alloc] init];
    });
    
    return presence;
}

#pragma mark - Connecting to server

- (void)fetchNumber:(RMTelepresence2PresenceFetchNumberCompletion)completion
{
    if (![UIDevice currentDevice].isDockableTelepresenceDevice) {
        return completion(nil);
    }
    
    NSString *host = [UIApplication environmentVariableWithKey:@"ROMO_TELEPRESENCE_SERVER"];
    NSString *udid = [UIDevice currentDevice].UDID;
    NSString *defaultsNumberKey = [NSString stringWithFormat:@"number:%@:%@", host, udid];
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    if ([defaults valueForKey:defaultsNumberKey]) {
        self.number = [defaults valueForKey:defaultsNumberKey];
        return completion(nil);
    }
    
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"http://%@/hosts/%@/number", host, udid]];
    NSURLRequest *request = [NSURLRequest requestWithURL:url];

    NSLog(@"Pinging url: %@...", url);
    
    [NSURLConnection sendAsynchronousRequest:request queue:[NSOperationQueue mainQueue] completionHandler:^(NSURLResponse *response, NSData *data, NSError *connectionError) {
        NSHTTPURLResponse *httpResponse = (id)response;

        NSLog(@"got response: %@", httpResponse);
        
        if (httpResponse.statusCode >= 200 && httpResponse.statusCode < 300) {
            NSDictionary *payload = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            self.number = payload[@"number"];
            
            [defaults setValue:self.number forKey:defaultsNumberKey];
            [defaults synchronize];
            
            completion(nil);
            
        } else if (connectionError) {
            DDLogError(@"Failed to fetch device number: %@", connectionError);
            completion(connectionError);
        } else {
            DDLogError(@"Failed to fetch device number: StatusCode %d", httpResponse.statusCode);
            
            NSError *err = [NSError errorWithDomain:@"com.romotive.telepresence" code:httpResponse.statusCode userInfo:nil];
            completion(err);
        }
    }];
}

- (void)connect
{
    if (![UIDevice currentDevice].isDockableTelepresenceDevice) {
        return;
    }
    
    if (!self.number) {
//        [self fetchNumber:^(NSError *error) {
//            if (!error) {
//                [self connect];
//            }
//        }];
        return;
    }
    
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(connect) object:nil];
    
    if (self.socket && self.socket.readyState != SR_CLOSED) {
        return;
    }
    
    NSString *host = [UIApplication environmentVariableWithKey:@"ROMO_TELEPRESENCE_SERVER"];
    NSString *protocol = [UIApplication environmentVariableWithKey:@"ROMO_TELEPRESENCE_WS_PROTOCOL"];
    
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"%@://%@/?number=%@", protocol, host, self.number]];
    NSURLRequest *request = [[NSURLRequest alloc] initWithURL:url];
    
    self.socket = [[SRWebSocket alloc] initWithURLRequest:request];
    self.socket.delegate = self;
    
    [self.socket open];
}

- (void)disconnect
{
    [self.socket closeWithCode:1000 reason:@"Client requested disconnect"];
    
    self.socket.delegate = nil;
    self.socket = nil;
}

- (void)callDidTimeout
{
    self.inCall = NO;
    
    RMAppDelegate *appDelegate = (RMAppDelegate *)[UIApplication sharedApplication].delegate;
    appDelegate.robotController = appDelegate.defaultController;
}

- (void)didReceiveIncomingCall:(NSDictionary *)payload
{
    if ([self.previousCallUUID isEqualToString:payload[@"uuid"]]) {
        // This is the second attempt call packet. We have already seen this call UUID,
        // so we can just ignore it.
        return;
    }
    
    self.previousCallUUID = payload[@"uuid"];
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSDate *lastConnectionAt = [defaults objectForKey:@"telepresence.lastConnectionAt"];
    NSString *lastClientUDID = [defaults objectForKey:@"telepresence.lastClientUDID"];
    
    DDLogInfo(@"Incoming call {UUID: %@, otSessionID: %@}", payload[@"uuid"], payload[@"otSessionID"]);
    
    if (self.isInCall && [lastClientUDID isEqualToString:payload[@"clientUDID"]]) {
        // If we are in a call but the caller is the client we are in call with, cancel the current
        // session and recreate it. This is a way to make sure that the users can recreate bad sessions
        // that we cannot detect due to edge cases in OpenTok.
        [self.hostController endSessionWithCompletion:^{
            
            double delayInSeconds = 1.0;
            dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
            dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
                self.inCall = YES;
                [self startTelepresenceControllerWithPayload:payload];
            });
        }];
        return;
        
    } else if (self.isInCall) {
        // We are in a call, and the caller is a new device.
        DDLogInfo(@"Ignoring incoming call – user is in a call with another client.");
        return;
    }
    
    [[RMAnalytics sharedInstance] track:@"Telepresence Host: Incoming Call" properties:@{@"uuid": payload[@"uuid"]}];
    
    RMAppDelegate *appDelegate = (RMAppDelegate *)[UIApplication sharedApplication].delegate;
    
    // Setup the call timeout
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(callDidTimeout) object:nil];
    [self performSelector:@selector(callDidTimeout) withObject:nil afterDelay:30];
    
    // Mark that we are in a call
    self.inCall = YES;
    
    
    
    if (lastConnectionAt &&
        [lastClientUDID isEqualToString:payload[@"clientUDID"]] &&
        [[NSDate date] timeIntervalSinceDate:lastConnectionAt] < kAutoAnswerCallBackWithin) {
        
        [[RMAnalytics sharedInstance] track:@"Telepresence Host: Accepted Call" properties:@{@"uuid": payload[@"uuid"], @"type": @"automatic"}];
        [self startTelepresenceControllerWithPayload:payload];
        
    } else {
        // Create and present the incoming call view controller
        RMTelepresenceIncomingCallVC *controller = [[RMTelepresenceIncomingCallVC alloc] init];
        
        controller.callAcceptedHandler = ^ {
            [[RMAnalytics sharedInstance] track:@"Telepresence Host: Accepted Call" properties:@{@"uuid": payload[@"uuid"], @"type": @"manual"}];
            [self startTelepresenceControllerWithPayload:payload];
        };
        
        controller.callRejectedHandler = ^ {
            [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(callDidTimeout) object:nil];
            [[RMAnalytics sharedInstance] track:@"Telepresence Host: Rejected Call" properties:@{@"uuid": payload[@"uuid"]}];
            appDelegate.robotController = appDelegate.defaultController;
            
            self.inCall = NO;
        };
        
        appDelegate.robotController = controller;
    }
}

- (void)startTelepresenceControllerWithPayload:(NSDictionary *)payload
{
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(callDidTimeout) object:nil];
    
    RMAppDelegate *appDelegate = (RMAppDelegate *)[UIApplication sharedApplication].delegate;
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:payload[@"clientUDID"] forKey:@"telepresence.lastClientUDID"];
    [defaults setObject:[NSDate date] forKey:@"telepresence.lastConnectionAt"];
    [defaults synchronize];
    
    self.hostController =
    [[RMTelepresenceHostRobotController alloc] initWithUUID:payload[@"uuid"]
                                                   sessionID:payload[@"otSessionID"]
                                                       token:payload[@"otToken"]
                                                  completion:^(NSError *error) {
                                                      if (error) {
                                                          DDLogVerbose(@"Error: %@", error);
                                                      }
                                                      
                                                      self.inCall = NO;
                                                      self.hostController = nil;
                                                      
                                                      appDelegate.robotController = appDelegate.defaultController;
                                                      
                                                      [defaults setObject:[NSDate date] forKey:@"telepresence.lastConnectionAt"];
                                                      [defaults synchronize];
                                                  }];
    
    appDelegate.robotController = self.hostController;
}

#pragma mark - SRWebSocketDelegate

- (void)webSocket:(SRWebSocket *)webSocket didReceiveMessage:(id)message
{
    if ([message respondsToSelector:@selector(hasPrefix:)] && [message hasPrefix:@":json:"]) {
        NSString *trimmedMessage = [message stringByReplacingOccurrencesOfString:@":json:" withString:@""];
        NSDictionary *payload = [NSJSONSerialization JSONObjectWithData:[trimmedMessage dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil];
        
        if ([payload[@"command"] isEqualToString:@"call"]) {
            [self didReceiveIncomingCall:payload];
        }
    }
}

- (void)webSocketDidOpen:(SRWebSocket *)webSocket
{
    DDLogVerbose(@"Telepresence web socket did open.");
}

- (void)webSocket:(SRWebSocket *)webSocket didFailWithError:(NSError *)error
{
    if (error.code == 2132) {
        DDLogError(@"It appears that the telepresence server is down.");
    }
    
    DDLogError(@"Socket failed: %@", error);
    
    // Retry connection after 5 seconds
    [self performSelector:@selector(connect) withObject:nil afterDelay:5];
}

- (void)webSocket:(SRWebSocket *)webSocket didCloseWithCode:(NSInteger)code reason:(NSString *)reason wasClean:(BOOL)wasClean
{
    if (wasClean) {
        DDLogVerbose(@"Socket closed cleanly: %i", code);
    } else {
        DDLogError(@"Socket closed uncleanly: %i, %@", code, reason);
    }
        
    [self performSelector:@selector(connect) withObject:nil afterDelay:5];
}

@end
