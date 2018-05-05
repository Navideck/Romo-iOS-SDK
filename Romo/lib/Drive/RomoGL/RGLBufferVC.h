//
//  AVViewController.h
//  Romo
//

#import <UIKit/UIKit.h>

#import <AVFoundation/AVFoundation.h>

#pragma mark - GLBufferViewController --

/**
 * An extended UIViewController used for drawing planes containing YUV420P data.
 */
@interface RGLBufferVC : UIViewController

@property (nonatomic) AVSampleBufferDisplayLayer *displayLayer;

#pragma mark - Initialization --

/**
 * Initializes the ViewController to display with the following frame.
 * Frame must be set now in order to properly set up the Texture Caches.
 * @return An Initialized GLTCViewController instance.
 * @param frame The CGRect used to display the ViewController's View.
 */
- (id)initWithFrame:(CGRect)frame;

#pragma mark - Methods --

- (void) playSampleBuffer:(CMSampleBufferRef) sampleBuffer;

@end
