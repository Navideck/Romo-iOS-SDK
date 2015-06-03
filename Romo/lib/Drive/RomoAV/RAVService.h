//
//  AVService.h
//  Romo
//

#import "RAVVideoInput.h"
#import "RAVVideoOutput.h"
#import "RMService.h"
#import "RMDataSocket.h"

#pragma mark - AVService --

/**
 * A Service class which provides AVStreaming for use during a Session.
 * Provides views for both the local preview and remote window, 
 * and awaits an AVSubscriber to whom it will send AV data.
 * @see AVSubscriber
 */
@interface RAVService : RMService <RMDataSocketDelegate>

+ (RAVService *)service;

#pragma mark - Methods --

/**
 * Returns the AVService remote streaming view.
 * @return The remote streaming UIView.
 */
- (UIView *)peerView;

@end
