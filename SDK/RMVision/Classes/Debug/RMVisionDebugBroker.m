//
//  RMVisionDebugBroker.m
//  RMVision
//
//  Created on 4/2/13.
//  Copyright (c) 2013 Romotive. All rights reserved.
//
#import "RMVisionDebugBroker.h"

#import <QuartzCore/QuartzCore.h>

#import "RMImageUtils.h"
#import "UIView+VisionAdditions.h"
#import "UIDevice+VisionHardware.h"
#import "RMBorderView.h"

// Some colors to use!
#define RMVISION_BLUE   [UIColor colorWithRed:(1.0/255.0) green:(174.0/255.0) blue:(221.0/255.0) alpha:1.0];
#define RMVISION_GREEN  [UIColor colorWithHue:0.38 saturation:1.0 brightness:0.85 alpha:1.0];

@interface RMVisionDebugBroker ()

@property (nonatomic, strong) NSMutableArray *outputViews;
@property (nonatomic, strong) NSMutableDictionary *trackedObjects;

@property (nonatomic, strong) UIView *motionView;
@property (nonatomic, strong) UIView *attentionView;

@property (nonatomic, strong) UILabel *fpsLabel;
@property (nonatomic) BOOL outputViewAdded;

@end

@implementation RMVisionDebugBroker

@synthesize core = _core;
@synthesize fps = _fps;

static RMVisionDebugBroker *sharedInstance = nil;

//------------------------------------------------------------------------------
+ (RMVisionDebugBroker *) shared {
    if (sharedInstance == nil) {
        sharedInstance = [[RMVisionDebugBroker alloc] init];
    }
    
    return sharedInstance;
}

//------------------------------------------------------------------------------
- (id)init
{
    self = [super init];
    if (self) {
        _outputViews = [[NSMutableArray alloc] init];
        _trackedObjects = [[NSMutableDictionary alloc] init];
        _running = NO;
    }
    return self;
}

//------------------------------------------------------------------------------
- (BOOL)addOutputView:(UIView *)view
{
    if ([self.outputViews containsObject:view]) {
        return NO;
    } else {
        [self.outputViews addObject:view];
        if (self.core.isRunning) {
            [self _addOutputView:view];
        }
        return YES;
    }
}

//------------------------------------------------------------------------------
- (void)_addOutputView:(UIView *)view
{
    [view addObserver:self
           forKeyPath:@"frame"
              options:NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew | NSKeyValueObservingOptionPrior
              context:NULL];
    
    self.core.videoPreviewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    self.core.videoPreviewLayer.frame = view.bounds;
    [view.layer insertSublayer:self.core.videoPreviewLayer atIndex:0];
    self.outputViewAdded = YES;
}

//------------------------------------------------------------------------------
- (void)visionStarted
{
    if (self.outputViews.count && !self.outputViewAdded) {
        [self _addOutputView:self.outputViews.firstObject];
    }
}

//------------------------------------------------------------------------------
- (BOOL)removeOutputView:(UIView *)view
{
    if (![self.outputViews containsObject:view]) {
        return NO;
    } else {
        [self.outputViews removeObject:view];
        if (self.outputViewAdded) {
            [view removeObserver:self forKeyPath:@"frame"];
            [self.core.videoPreviewLayer removeFromSuperlayer];
            self.outputViewAdded = NO;
            return YES;
        } else {
            return NO;
        }
    }
}

//------------------------------------------------------------------------------
- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context {
    if ([keyPath isEqualToString:@"frame"]) {
        CGRect newFrame = CGRectNull;
        if ([object valueForKeyPath:keyPath] != [NSNull null] && change[@"new"]) {
            newFrame = [[object valueForKeyPath:keyPath] CGRectValue];
            self.core.videoPreviewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
            self.core.videoPreviewLayer.frame = CGRectMake(0, 0, newFrame.size.width, newFrame.size.height);
        }
    }
}

//------------------------------------------------------------------------------
- (void)addMotionView
{
    if (self.outputViews.count) {
        UIView *parentView = self.outputViews.firstObject;
        self.motionView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, parentView.frame.size.width, parentView.frame.size.height)];
        self.motionView.contentMode = UIViewContentModeScaleAspectFill;
        self.motionView.backgroundColor = [UIColor clearColor];
        self.motionView.alpha = 0.35;
        [parentView addSubview:self.motionView];
    }
}

//------------------------------------------------------------------------------
- (void)disableMotionView
{
    if (self.outputViews.count) {
        [self.motionView removeFromSuperview];
        self.motionView = nil;
    }
}

//------------------------------------------------------------------------------
- (void)updateMotionView:(UIImage *)newImage
{
    if (self.motionView) {
        [_motionView performSelectorOnMainThread:@selector(setImage:)
                                      withObject:newImage
                                   waitUntilDone:NO];
    }
}

//------------------------------------------------------------------------------
- (void)addAttentionView
{
    UIView *parentView = self.outputViews.firstObject;
    if (parentView) {
        self.attentionView = [[UIView alloc] initWithFrame:CGRectMake(40, 40, 20, 20)];
        self.attentionView.layer.cornerRadius = 10;
        self.attentionView.backgroundColor = [UIColor blueColor];
        self.attentionView.layer.borderColor = [UIColor whiteColor].CGColor;
        self.attentionView.layer.borderWidth = 2.0f;
        self.attentionView.contentMode = UIViewContentModeScaleAspectFill;
        self.attentionView.alpha = 0.0;
        self.attentionView.hidden = YES;
        [parentView addSubview:self.attentionView];
    }
}

//------------------------------------------------------------------------------
- (void)loseAttention
{
    UIView *parentView = self.outputViews.firstObject;
    if (parentView) {
        [UIView animateWithDuration:0.25
                              delay:0.0
                            options:UIViewAnimationOptionCurveEaseInOut
                         animations:^(void) {
                             self.attentionView.alpha = 0.5;
                         }
                         completion:^(BOOL finished) {
                             self.attentionView.hidden = YES;
                         }];
    }
}

//------------------------------------------------------------------------------
- (void)setAttention:(CGPoint)attention
{
    UIView *parentView = self.outputViews.firstObject;
    if (parentView) {
        CGRect roi = [RMImageUtils frameObject:CGRectMake(attention.x, attention.y, 1, 1)
                                  withinBounds:parentView.bounds];
    
        self.attentionView.center = CGPointMake(roi.origin.x*-1, roi.origin.y);
        [self.attentionView setNeedsDisplay];
        if (self.attentionView.hidden) {
            self.attentionView.hidden = NO;
            [UIView animateWithDuration:0.2
                             animations:^(void){
                                 self.attentionView.alpha = 1.0;
                             }];
        }
    }
}

//------------------------------------------------------------------------------
- (void)objectAt:(CGRect)bounds
    withRotation:(float)rotation
        withName:(NSString *)objectId
{
    UIView *parentView = self.outputViews.firstObject;
    if (parentView) {
        UIColor *color;
        if ([objectId isEqualToString:@"Face"]) {
            color = RMVISION_BLUE;
        } else {
            color = RMVISION_GREEN;
        }
        [self drawBox:[RMImageUtils frameObject:bounds
                                   withinBounds:parentView.bounds]
            withColor:color
            withLabel:objectId
         withRotation:rotation];
    }
}

//------------------------------------------------------------------------------
- (void)drawBox:(CGRect)bounds
      withColor:(UIColor *)color
      withLabel:(NSString *)objectId
   withRotation:(float)rotation
{
    UIView *parentView = self.outputViews.firstObject;
    if (parentView) {
        RMBorderView *border = [self.trackedObjects objectForKey:objectId];
        
        if (!border) {
            border = [[RMBorderView alloc] initWithFrame:CGRectMake(0, 0, parentView.width, parentView.height)];
            border.strokeColor = color;
            border.label = objectId;
            [self.trackedObjects setObject:border forKey:objectId];
            [parentView addSubview:border];
        } else {
            border.location = bounds;
            border.rotation = rotation;
            [border setNeedsDisplay];
        }
    }
}

//------------------------------------------------------------------------------
- (void)forgetBox:(NSString *)objectId
{
    RMBorderView *border = [self.trackedObjects objectForKey:objectId];
    
    if (border) {
        [border removeFromSuperview];
        [self.trackedObjects removeObjectForKey:objectId];
    }
}

//------------------------------------------------------------------------------
- (void)loseObject:(NSString *)objectId
{
    [self forgetBox:objectId];
}

#pragma mark - Property overriding
//------------------------------------------------------------------------------
- (void)setCore:(RMVision *)core
{
    _core = core;
    self.running = YES;
}

//------------------------------------------------------------------------------
- (RMVision *)core
{
    return _core;
}

//------------------------------------------------------------------------------
- (void)setFps:(float)fps
{
    _fps = fps;
    if (self.showFPS) {
        self.fpsLabel.text = [NSString stringWithFormat:@"FPS: %0.1f", fps];
    }
}

//------------------------------------------------------------------------------
- (float)fps
{
    return _fps;
}

//------------------------------------------------------------------------------
- (UILabel *)fpsLabel
{
    if (!_fpsLabel) {
        UIView *parentView = self.outputViews.firstObject;
        if (parentView) {
            _fpsLabel = [[UILabel alloc] initWithFrame:CGRectMake(5, parentView.bounds.size.height - 30, parentView.bounds.size.width, 30)];
            _fpsLabel.font = [UIFont boldSystemFontOfSize:16.0];
            _fpsLabel.backgroundColor = [UIColor clearColor];
            _fpsLabel.textColor = RMVISION_BLUE;
            _fpsLabel.text = @" FPS: --";
            [parentView addSubview:_fpsLabel];
        }
    }
    return _fpsLabel;
}

@end
