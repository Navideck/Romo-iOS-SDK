//
//  GLView.m
//  RomoGL
//

#import "RGLBufferView.h"

#import <OpenGLES/EAGLDrawable.h>
#import <QuartzCore/QuartzCore.h>

#pragma mark - GLBufferView (Private) --

@interface RGLBufferView ()
{
    EAGLContext *_context;
    
    GLuint _renderBuffer, _frameBuffer;
    GLint _bufferWidth, _bufferHeight;
}

- (BOOL)createFramebuffers;

@end

#pragma mark -
#pragma mark - Implementation (GLBufferView) --

@implementation RGLBufferView

#pragma mark - Properties --

@synthesize context=_context;

#pragma mark - Initialization --

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self)  {
		CAEAGLLayer *eaglLayer = (CAEAGLLayer *)self.layer;
		eaglLayer.opaque = YES;
		eaglLayer.drawableProperties = @{kEAGLDrawablePropertyRetainedBacking: @(NO), kEAGLDrawablePropertyColorFormat: kEAGLColorFormatRGBA8};	
        
        self.context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
        
        if (!_context || ![EAGLContext setCurrentContext:_context] || ![self createFramebuffers]) {
			return nil;
		}
    }
    return self;
}

#pragma mark - Methods --

- (BOOL)presentFramebuffer;
{
    BOOL success = NO;
    if (_context) {
        [EAGLContext setCurrentContext:_context];
        glBindRenderbuffer(GL_RENDERBUFFER, _renderBuffer);

        success = [_context presentRenderbuffer:GL_RENDERBUFFER];
    }
    return success;
}

- (BOOL)createFramebuffers
{	
	glDisable(GL_DEPTH_TEST);
    
	// Onscreen framebuffer object
	glGenFramebuffers(1, &_frameBuffer);
	glBindFramebuffer(GL_FRAMEBUFFER, _frameBuffer);
	
	glGenRenderbuffers(1, &_renderBuffer);
	glBindRenderbuffer(GL_RENDERBUFFER, _renderBuffer);
	
	[_context renderbufferStorage:GL_RENDERBUFFER fromDrawable:(CAEAGLLayer*) self.layer];
    
	glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, _renderBuffer);
	
	glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_WIDTH, &_bufferWidth);
	glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_HEIGHT, &_bufferHeight);
	
	if (glCheckFramebufferStatus(GL_FRAMEBUFFER) != GL_FRAMEBUFFER_COMPLETE) {
		NSLog(@"Failed to generate Framebuffer.");
		return NO;
	}
    
    glBindFramebuffer(GL_FRAMEBUFFER, _frameBuffer);
    glViewport(0, 0, _bufferWidth, _bufferHeight);
    
	return YES;
}

// Override the class method to return the OpenGL layer, as opposed to the normal CALayer
+ (Class)layerClass
{
	return [CAEAGLLayer class];
}

@end
