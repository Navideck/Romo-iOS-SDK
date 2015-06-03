//
//  GLView.h
//  RomoGL
//

#import <UIKit/UIKit.h>
#import <OpenGLES/EAGL.h>
#import <OpenGLES/ES2/gl.h>
#import <OpenGLES/ES2/glext.h>

#pragma mark - GLBufferView --

/**
 * An overriden UIView used by a GLBufferViewController to draw to the screen
 * off of the main thread.
 */
@interface RGLBufferView : UIView

#pragma mark - Properties --

/// The OpenGLES Graphics Context to use for rendering.
@property (nonatomic, strong) EAGLContext *context;

#pragma mark - Methods --

/**
 * Swaps the Framebuffers from the back store to the screen, updating the rendered content.
 * @return Whether or not the swap was successful.
 */
- (BOOL)presentFramebuffer;

@end
