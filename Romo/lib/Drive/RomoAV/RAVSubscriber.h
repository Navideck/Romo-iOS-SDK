//
//  AVSubscriber.h
//  RomoLibrary
//
//

#import "RMSubscriber.h"
#import "RAVService.h"
#import "RMSocket.h"

/**
 * A Service class which provides AVStreaming for use during a Session.
 * Provides views for both the local preview and remote window,
 * and awaits an AVSubscriber to whom it will send AV data.
 * @see AVSubscriber
 */
@interface RAVSubscriber : RMSubscriber <RMDataSocketDelegate, RMVideoInputDelegate>

@property (nonatomic, readonly, strong) RAVVideoInput *videoInput;

/**
 * Creates a new Subscriber, and connects it to the provided Service.
 */
+ (RAVSubscriber *)subscriberWithService:(RAVService *)service;

@end
