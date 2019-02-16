//
//  RMWebSocket.h
//  Romo3
//
//  Created on 5/1/13.
//  Copyright (c) 2013 Romotive. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef void(^RMWebSocketHandler)(id data);
typedef void(^RMWebSocketAckBlock)(id data);

typedef enum RMWebSocketState {
    RMWebSocketStateConnecting,
    RMWebSocketStateConnected,
    RMWebSocketStateDisconnected
} RMWebSocketState;

@protocol RMWebSocketDelegate;

@interface RMWebSocket : NSObject

@property (nonatomic, weak) id <RMWebSocketDelegate> delegate;
@property (nonatomic, assign) RMWebSocketState state;
@property (nonatomic, readonly, strong) NSString *name;

- (id)initWithName:(NSString *)name host:(NSString *)host delegate:(id <RMWebSocketDelegate>)delegate;

- (void)sendEvent:(NSString *)event withData:(id)data;
- (void)sendEvent:(NSString *)event withData:(id)data completion:(RMWebSocketAckBlock)ackBlock;
- (void)sendCommand:(NSString *)name withData:(id)data;
- (void)sendCommand:(NSString *)name withData:(id)data completion:(RMWebSocketAckBlock)ackBlock;

- (void)addTarget:(id)target action:(SEL)action forEvent:(NSString *)name;
- (void)removeHandlersForTarget:(id)target;
- (void)removeHandlersForEvent:(NSString *)name;
- (void)removeAllHandlers;

@end

@protocol RMWebSocketDelegate <NSObject>

@optional

- (void)webSocket:(RMWebSocket *)socket didDisconnectWithError:(NSError *)error;
- (void)webSocket:(RMWebSocket *)socket didReceiveError:(NSError *)error;

@end
