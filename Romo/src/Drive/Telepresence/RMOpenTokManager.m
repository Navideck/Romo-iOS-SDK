//
//  RMOpenTokManager.m
//  Romo
//
//  Created on 11/11/13.
//  Copyright (c) 2013 Romotive. All rights reserved.
//

#import "RMOpenTokManager.h"
#import "RMTelepresence.h"
#import <Opentok/Opentok.h>
#import <CocoaLumberjack/CocoaLumberjack.h>

NSString * const kTelepresenceErrorDomain = @"com.romotive.telepresence";
static NSString * const kOpenTokApiKey = @"13527102";

@interface RMOpenTokManager () //<OTSessionDelegate, OTPublisherDelegate, OTSubscriberDelegate>

// Private properties
@property (nonatomic, strong) NSString *sessionID;
@property (nonatomic, strong) NSString *token;
@property (nonatomic, strong) NSError *error;

// Make public readonly properties internally readwrite
@property (nonatomic, strong, readwrite) NSString *uuid;
@property (nonatomic, strong, readwrite) OTSession *otSession;
@property (nonatomic, strong, readwrite) OTPublisher *otPublisher;
@property (nonatomic, strong, readwrite) OTSubscriber *otSubscriber;

@end

@implementation RMOpenTokManager

- (instancetype)initWithUUID:(NSString *)uuid sessionID:(NSString *)sessionID token:(NSString *)token
{
    self = [super init];
    if (self) {
        _uuid = uuid;
        _sessionID = sessionID;
        _token = token;
        
//        _otSession = [[OTSession alloc] initWithSessionId:self.sessionID delegate:self];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(applicationWillResignActiveNotification:)
                                                     name:UIApplicationWillResignActiveNotification
                                                   object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(applicationDidBecomeActiveNotification:)
                                                     name:UIApplicationDidBecomeActiveNotification
                                                   object:nil];
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    if (self.otSession) {
        // Dealloc should only happen after the session disconnects, which nils the otSession
        // property. So if we get here, the owner of the OTManager failed to properly disconnect
        // the session before releasing its handle.
        DDLogWarn(@"WARNING: RMOpenTokManager dealloc being called without a nil otSession.");
    }
    
    DDLogVerbose(@" ------------------ ");
}

#pragma mark - Responding to app changes

- (void)applicationDidBecomeActiveNotification:(NSNotification *)notification
{
//    self.otPublisher.publishVideo = YES;
//    self.otSubscriber.subscribeToVideo = YES;
}

- (void)applicationWillResignActiveNotification:(NSNotification *)notification
{
//    self.otPublisher.publishVideo = NO;
//    self.otSubscriber.subscribeToVideo = NO;
    [self disconnect];
}

#pragma mark - Connecting and disconnecting to OpenTok service

- (void)connect
{
//    [self.otSession connectWithApiKey:kOpenTokApiKey token:self.token];
}

- (void)disconnect
{
    if (self.otSession && self.otSession.sessionConnectionStatus == OTSessionConnectionStatusConnected) {
        DDLogError(@"[%@] OpenTok Session Disconnecting", self.uuid);
        [self disconnectFromOpenTok];
    } else {
        if ([self.delegate respondsToSelector:@selector(otSessionManagerDidDisconnect:)]) {
            [self.delegate otSessionManagerDidDisconnect:nil];
        }
    }
}

- (void)disconnectFromOpenTok
{
    if (self.otSession.sessionConnectionStatus)
        
        if (self.otPublisher) {
//            [self.otSession unpublish:self.otPublisher];
        }
    
    self.otSubscriber.subscribeToVideo = NO;
//    [self.otSession disconnect];
}

- (void)addTarget:(id)target action:(SEL)action forSignal:(NSString *)eventName
{
//    __weak id wtarget = target;
    
//    [self.otSession receiveSignalType:eventName withHandler:^(NSString *type, id data, OTConnection *fromConnection) {
//        // The compiler would normally warn about how performSelector may leak. Since the selector we are invoking will
//        // not return anything, we don't have to worry about anything leaking.
//#pragma clang diagnostic push
//#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
//        [wtarget performSelector:action withObject:data];
//#pragma clang diagnostic pop
//    }];
}

#pragma mark - OTSessionDelegate

- (void)sessionDidConnect:(OTSession *)session
{
    DDLogError(@"[%@] OpenTok Session Connected", self.uuid);
    
    if (self.otPublisher) {
        // Something strange happened.. ABORT!
        [self disconnect];
        return;
    }
    
//    self.otPublisher = [[OTPublisher alloc] initWithDelegate:self];
    self.otPublisher.publishAudio = YES;
    self.otPublisher.publishVideo = YES;
    
//    [session publish:self.otPublisher];
    
    if ([self.delegate respondsToSelector:@selector(otSessionManagerDidConnect:)]) {
        [self.delegate otSessionManagerDidConnect:self];
    }
}

- (void)sessionDidDisconnect:(OTSession *)session
{
    DDLogError(@"[%@] OpenTok Session Disconnected", self.uuid);
    
    self.otSession.delegate = nil;
    self.otSession = nil;
    
    if (self.error) {
        if ([self.delegate respondsToSelector:@selector(otSessionManager:didEncounterUnhandlableError:)]) {
            [self.delegate otSessionManager:self didEncounterUnhandlableError:self.error];
        }
    } else {
        if ([self.delegate respondsToSelector:@selector(otSessionManagerDidDisconnect:)]) {
            [self.delegate otSessionManagerDidDisconnect:self];
        }
    }
}

/**
 * Sent if the session fails to connect, some time after your applications sends the
 * [OTSession connectWithApiKey:token:] message.
 */
- (void)session:(OTSession*)session didFailWithError:(OTError*)error
{
    DDLogError(@"[%@] OpenTok Error\n  - Error code: %i\n  - Description: %@", self.uuid, error.code, error.localizedDescription);
    
    NSError *err = nil;
    
    switch ((OTSessionErrorCode)error.code) {
        case OTConnectionFailed:
        case OTSessionConnectionTimeout:
//        case OTUnknownServerError:
        case OTSessionStateFailed:
        case OTConnectionRefused:
            err = [NSError errorWithDomain:kTelepresenceErrorDomain
                                      code:RMTelepresenceErrorCodeConnectionFailed
                                  userInfo:nil];
            break;
            
        case OTP2PSessionMaxParticipants:
            err = [NSError errorWithDomain:kTelepresenceErrorDomain
                                      code:RMTelepresenceErrorCodeConnectionTooManyParticipants
                                  userInfo:nil];
            break;
            
//        case OTSDKUpdateRequired:
//            err = [NSError errorWithDomain:kTelepresenceErrorDomain
//                                      code:RMTelepresenceErrorCodeConnectionUpdateRequired
//                                  userInfo:nil];
//            break;
            
        default:
            break;
    }
    
    if ([self.delegate respondsToSelector:@selector(otSessionManager:didEncounterUnhandlableError:)]) {
        [self.delegate otSessionManager:self didEncounterUnhandlableError:err];
    }
}

- (void)session:(OTSession *)session didReceiveStream:(OTStream *)stream
{
    if ([stream.connection.connectionId isEqualToString:session.connection.connectionId]) {
        // Own stream
    } else {
        if (!self.otSubscriber) {
//            self.otSubscriber = [[OTSubscriber alloc] initWithStream:stream delegate:self];
            self.otSubscriber.subscribeToAudio = YES;
            self.otSubscriber.subscribeToVideo = YES;
        }
    }
}

- (void)session:(OTSession *)session didDropStream:(OTStream *)stream
{
    DDLogVerbose(@"Dropped stream: %@. Stream count: %i", stream, session.streams.count);
}

- (void)session:(OTSession *)session didCreateConnection:(OTConnection *)connection
{
    DDLogVerbose(@"[%@] OpenTok Peer Connection Established", self.uuid);
}

- (void)session:(OTSession *)session didDropConnection:(OTConnection *)connection
{
    DDLogVerbose(@"[%@] OpenTok Peer Connection Dropped", self.uuid);
    
    // Note that the following if removed might seem to work the same as with it. Although
    // it might appear fine, it helps prevent timing crashes from occuring when ot sessions
    // teardown and things are dealloced.
    
    self.otSubscriber.subscribeToVideo = NO;
    self.otPublisher.publishVideo = NO;
    
    [self.otSubscriber.view removeFromSuperview];
    [self.otPublisher.view removeFromSuperview];
    
    // -- OpenTok EDGE CASE
    // Do not unpublish here or a random edge case bug might appear when sessions end. This
    // was at one time thought to fix another issue that the delay below "resolves"
    //    [session unpublish:self.otPublisher];
    
    
    // -- OpenTok EDGE CASE
    // This is a crappy delay. It is required to ensure that the camera properly shuts down
    // before stuff is dealloced. Sad, but it seems to "fix" the issue 9 times out of 10.
    //
    // The crash log looks something like the following:
    //
    // 0   libobjc.A.dylib                 0x3aa285b6 objc_msgSend + 22
    // 1   Romo                            0x00756d50 -[RTCVideoDriver dealloc] + 52
    // 2   AVFoundation                    0x31e9eed6 __74-[AVCaptureVideoDataOutput _AVCaptureVideoDataOutput_VideoDataBecameReady]_block_invoke_0 + 294
    //
    double delayInSeconds = 4.0;
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
//        [session disconnect];
    });
}

#pragma mark - OTPublisherDelegate

- (void)publisher:(OTPublisher*)publisher didFailWithError:(OTError*)error
{
    DDLogError(@"[%@] OpenTok Publisher Error\n  - Error code: %i\n  - Description: %@", self.uuid, error.code, error.localizedDescription);
    
//    switch ((OTPublisherErrorCode)error.code) {
//        case OTSessionDisconnected:
//            break;
//            
//        case OTUserDeniedCameraAccess:
//            break;
//            
//        case OTNoMediaPublished:
//            break;
//    }
}

-(void)publisherDidStartStreaming:(OTPublisher *)publisher
{
    
}

-(void)publisherDidStopStreaming:(OTPublisher *)publisher
{
    
}

-(void)publisher:(OTPublisher *)publisher didChangeCameraPosition:(AVCaptureDevicePosition)position
{
    
}

#pragma mark - OTSubscriberDelegate

- (void)subscriberDidConnectToStream:(OTSubscriber *)subscriber
{
    if ([self.delegate respondsToSelector:@selector(otSessionManager:subscriberDidConnect:)]) {
        [self.delegate otSessionManager:self subscriberDidConnect:subscriber];
    }
}

- (void)subscriber:(OTSubscriber *)subscriber didFailWithError:(OTError *)error
{
    DDLogError(@"[%@] OpenTok Subscriber Error\n  - Error code: %i\n  - Description: %@", self.uuid, error.code, error.localizedDescription);
    
    self.error = [NSError errorWithDomain:kTelepresenceErrorDomain
                                     code:RMTelepresenceErrorCodeConnectionSubscriberFailed
                                 userInfo:nil];
    
//    switch ((OTSubscriberErrorCode)error.code) {
//        case OTFailedToConnect:
//        case OTConnectionTimedOut:
//        case OTInitializationFailure:
//            break;
//            
//        default:
//            break;
//    }
//    
//    [self.otSession disconnect];
}

- (void)subscriberVideoDataReceived:(OTSubscriber *)subscriber
{
    DDLogVerbose(@"[%@] Got first frame from subscriber!", self.uuid);
    
    if ([self.delegate respondsToSelector:@selector(otSessionManager:didDecodeFirstVideoFrameFromSubscriber:)]) {
        [self.delegate otSessionManager:self didDecodeFirstVideoFrameFromSubscriber:subscriber];
    }
}

- (void)stream:(OTStream *)stream didChangeVideoDimensions:(CGSize)dimensions
{
    
}

- (void)subscriberVideoDisabled:(OTSubscriber *)subscriber
{
    
}


@end
