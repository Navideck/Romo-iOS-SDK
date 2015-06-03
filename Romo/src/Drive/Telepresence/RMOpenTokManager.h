//
//  RMOpenTokManager.h
//  Romo
//
//  Created on 11/11/13.
//  Copyright (c) 2013 Romotive. All rights reserved.
//

/**

 Responsibilities
 
 1) Connect to OpenTok session
 2) Retry connections when they fail
 3) Bubble up errors that happen that can't be internally handled
 4) Ensure safety with retain cycles and signal blocks
 
*/

#import <Foundation/Foundation.h>

@class OTSession, OTPublisher, OTSubscriber;
@protocol RMOpenTokManagerDelegate;

@interface RMOpenTokManager : NSObject

@property (nonatomic, weak) id <RMOpenTokManagerDelegate> delegate;

@property (nonatomic, strong, readonly) NSString *uuid;
@property (nonatomic, strong, readonly) OTSession *otSession;
@property (nonatomic, strong, readonly) OTPublisher *otPublisher;
@property (nonatomic, strong, readonly) OTSubscriber *otSubscriber;

- (instancetype)initWithUUID:(NSString *)uuid sessionID:(NSString *)sessionID token:(NSString *)token;

- (void)connect;
- (void)disconnect;

- (void)addTarget:(id)target action:(SEL)action forSignal:(NSString *)eventName;

@end

@protocol RMOpenTokManagerDelegate <NSObject>

@optional

/**
 * Called once when the OpenTok session connects to the OpenTok servers. The other
 * user (subscriber) is not yet in the session, but the publisher has been setup.
 */
- (void)otSessionManagerDidConnect:(RMOpenTokManager *)manager;

/**
 * Called once  when the OpenTok session disconnects. Owners of the manager should wait
 * until this delegate method is called before releasing it. This is to ensure that
 * the OpenTok stack has been released properly.
 */
- (void)otSessionManagerDidDisconnect:(RMOpenTokManager *)manager;

/**
 * Called once when the subscriber has entered the session. At this point the view in the subscriber view
 * can be used.
 */
- (void)otSessionManager:(RMOpenTokManager *)manager subscriberDidConnect:(OTSubscriber *)subscriber;

/**
 * Called once when the first video frame from the subscriber is decoded. After this point we know that
 * video is being streamed.
 */
- (void)otSessionManager:(RMOpenTokManager *)manager didDecodeFirstVideoFrameFromSubscriber:(OTSubscriber *)subscriber;

@required

/**
 * Called once if the session manager encounters an error that it cannot internally handle. The session
 * has already been disconnected if it was running. The delegate will *not* receive a call to
 * `otSessionManagerDidDisconnect:`
 */
- (void)otSessionManager:(RMOpenTokManager *)manager didEncounterUnhandlableError:(NSError *)error;

@end
