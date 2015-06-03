///////////////////////////////////////////////////////////////////////////////
//                             _
//                            | | (_)
//   _ __ ___  _ __ ___   ___ | |_ ___   _____
//  | '__/ _ \| '_ ` _ \ / _ \| __| \ \ / / _ \
//  | | | (_) | | | | | | (_) | |_| |\ V /  __/
//  |_|  \___/|_| |_| |_|\___/ \__|_| \_/ \___|
//
////////////////////////////////////////////////////////////////////////////////
//
//  RMFaceDetectionModule.mm
//      Uses OpenCV to perform facial detection
//  RMVision
//
//  Created on 10/28/12.
//  Copyright (c) 2012 Romotive. All rights reserved.
//
////////////////////////////////////////////////////////////////////////////////
#import "RMFaceDetectionModule.h"

#import "RMVision.h"
#import "RMImageUtils.h"
#import "RMVisionObjects.h"

#import "RMVisionDebugBroker.h"

#define SYSTEM_VERSION_LESS_THAN(v) ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] == NSOrderedAscending)

// Face detection configuration options
//==============================================================================
// Names of haar cascade resources
NSString * const kFrontalFaceCascadePath    = @"haarcascade_frontalface_alt2";
NSString * const kProfileFaceCascadePath    = @"haarcascade_profileface";
NSString * const kEyeCascadePath            = @"haarcascade_eye";

// Timeout default
const float kDefaultFaceTimeout = 0.8;

// Options for haar cascades
const int kHaarOptions =  CV_HAAR_FIND_BIGGEST_OBJECT | CV_HAAR_DO_ROUGH_SEARCH;
const uint32_t kFaceSwitchTimeout = 4;

// Scale factor for shrinking image
const float kScaleFactorSlow = 0.4;
const float kScaleFactorFast = 0.6;

// Offset for AVCapture roll orientation
const float kAVCaptureRollOffset = 270.0;

// Private members
//==============================================================================
@interface RMFaceDetectionModule ()

@property (nonatomic) cv::CascadeClassifier   frontalFaceCascade;
@property (nonatomic) cv::CascadeClassifier   profileFaceCascade;
@property (nonatomic) cv::CascadeClassifier   eyeCascade;

@property (nonatomic) CGPoint                 curFocus;
@property (nonatomic) int                     numFaces;

@property (nonatomic) BOOL                    frontFaceMode;
@property (nonatomic) BOOL                    trackingFace;
@property (nonatomic) uint32_t                lastFaceFrame;
@property (nonatomic) CFAbsoluteTime          timeFirstSeen;

@property (nonatomic) BOOL                    usesAVFoundation;
@property (nonatomic) AVCaptureMetadataOutput *metadataOutput;

@property (nonatomic) NSTimer                 *resetTimer;

@end

// Class Implementation
//==============================================================================
@implementation RMFaceDetectionModule

#pragma mark - Initialization / Teardown

// Initializes the face detector
//------------------------------------------------------------------------------
- (id) initWithVision:(RMVision *)core
{
    self = [super initModule:RMVisionModule_FaceDetection
                  withVision:core];
    
    if (self) {
        // Don't need color for face detection
        self.isColor = NO;
        _timeout = kDefaultFaceTimeout;

        _numFaces = 0;
        _frontFaceMode = YES;
        _trackingFace = NO;
        _lastFaceFrame = -1;
        
        [_resetTimer invalidate];
        
        // Set the scale factor
        self.scaleFactor = (self.isSlow ? kScaleFactorSlow : kScaleFactorFast);
        
        // Try to set up AVFoundation detection (returns NO if not available)
        _usesAVFoundation = [self setupAVFoundationFaceDetection];
        if (!_usesAVFoundation) {
            // Load the Haar cascades
            NSString* mainBundlePath = [[NSBundle mainBundle] resourcePath];
            NSString* frameworkBundlePath = [mainBundlePath stringByAppendingPathComponent:@"RMVision.bundle"];
            NSBundle* visionBundle = [NSBundle bundleWithPath:frameworkBundlePath];
            
            NSString *frontalFaceCascadePath = [visionBundle pathForResource:kFrontalFaceCascadePath ofType:@"xml"];
            if (!_frontalFaceCascade.load([frontalFaceCascadePath UTF8String])) {
                NSLog(@"Could not load face cascade: %@", frontalFaceCascadePath);
            }
            
            NSString *profileFaceCascadePath = [visionBundle pathForResource:kProfileFaceCascadePath ofType:@"xml"];
            if (!_profileFaceCascade.load([profileFaceCascadePath UTF8String])) {
                NSLog(@"Could not load face cascade: %@", profileFaceCascadePath);
            }
        }
    }

    return self;
}

// Shuts down the module
//------------------------------------------------------------------------------
- (void)shutdown
{
    if (self.usesAVFoundation) {
        [self teardownAVFoundationFaceDetection];
    }
    [super shutdown];
    
    [_resetTimer invalidate];

    [[RMVisionDebugBroker shared] loseObject:@"Face"];
}

- (void)dealloc
{
    [_resetTimer invalidate];
}

// Attempts to set up the AVCaptureMetadata face detection
//      (iOS 6+ and iPhone 4S+ or iPad2+)
//------------------------------------------------------------------------------
- (BOOL)setupAVFoundationFaceDetection
{
    self.metadataOutput = [[AVCaptureMetadataOutput alloc] init];
    if ( ![self.vision.session canAddOutput:self.metadataOutput] ) {
        self.metadataOutput = nil;
        return NO;
    }
    
    // Metadata processing will be fast, and mostly updating UI which should be done on the main thread
    // So just use the main dispatch queue instead of creating a separate one
    [self.metadataOutput setMetadataObjectsDelegate:self queue:dispatch_get_main_queue()];
    [self.vision.session addOutput:self.metadataOutput];
    
    if ( ![self.metadataOutput.availableMetadataObjectTypes containsObject:AVMetadataObjectTypeFace] ) {
        [self.vision.session removeOutput:self.metadataOutput];
        self.metadataOutput = nil;
        return NO;
    }
    
    // Only faces (if we don't set this we would detect everything available)
    self.metadataOutput.metadataObjectTypes = @[ AVMetadataObjectTypeFace ];
    
    return YES;
}

// Tears down the AVFoundation face detection
//------------------------------------------------------------------------------
- (void)teardownAVFoundationFaceDetection
{
	if (self.metadataOutput) {
		[self.vision.session removeOutput:self.metadataOutput];
    }
	self.metadataOutput = nil;
}

#pragma mark - Image Processing

// Runs the face detection (OpenCV)
//------------------------------------------------------------------------------
-(void)processFrame:(const cv::Mat)mat
          videoRect:(CGRect)rect
   videoOrientation:(AVCaptureVideoOrientation)videoOrientation
{
    [super processFrame:mat videoRect:rect videoOrientation:videoOrientation];
    
    // Save frame and scale appropriately
    cv::Mat localMat = [super resizeFrame:mat videoRect:rect];

    // Flip image when using the front camera if it hasn't been flipped
    if (self.vision.camera == RMCamera_Front && !self.vision.imageFlipped) {
        cv::flip(localMat, localMat, 1);
    }
    
    // Convert to greyscale
//    if (![self.vision isGrayscaleMode]) {
        cv::cvtColor(localMat, localMat, CV_BGR2GRAY);
//    }

    if (localMat.type() == CV_8UC1) {
        cv::equalizeHist(localMat, localMat);
    }
    self.output = localMat;
    self.frameProcessed = YES;
    
    // No need to do anything if we are using AVFoundation (yay GPU!)
    if (self.usesAVFoundation) {
        return;
    }
    
    // Detect faces
    std::vector<cv::Rect> faces;
    
    if (self.frontFaceMode || self.isSlow) {
        self.frontalFaceCascade.detectMultiScale(localMat, faces, 1.1, 2, kHaarOptions, cv::Size(60, 60));
        if (!faces.size()) {
            if ( (self.frameNumber - self.lastFaceFrame) > kFaceSwitchTimeout ) {
                self.frontFaceMode = NO;
            }
        } else {
            self.lastFaceFrame = self.frameNumber;
        }
    } else {
        self.profileFaceCascade.detectMultiScale(localMat, faces, 1.1, 3, kHaarOptions, cv::Size(40, 40));
        if (!faces.size()) {
            if ( (self.frameNumber - self.lastFaceFrame) > kFaceSwitchTimeout ) {
                self.frontFaceMode = YES;
            }
        } else {
            self.lastFaceFrame = self.frameNumber;
        }
    }
    
    // If we have faces in our last detection
    if (faces.size()) {
	// Build an RMFace object
        RMFace *face = [[RMFace alloc] init];
        
        if (!self.trackingFace) {
            self.trackingFace = YES;
            self.timeFirstSeen = CACurrentMediaTime();
            face.justFound = YES;
        } else {
            face.justFound = NO;
        }
        
        // Invalidate the timer
        [self.resetTimer invalidate];
        
        // Convert to NSMutableArray
        NSMutableArray *newFaces = [[NSMutableArray alloc] init];
        for (int i = 0; i < faces.size(); i++) {
            [newFaces addObject:[NSValue valueWithCGRect:CGRectMake(faces[i].x,
                                                                    faces[i].y,
                                                                    faces[i].width,
                                                                    faces[i].height)]];
        }

        for (int i = 0; i < [newFaces count]; i++) {
            CGRect faceRect = [[newFaces objectAtIndex:i] CGRectValue];
            faceRect = [RMImageUtils normalizeObject:faceRect
                                         withinFrame:CGRectMake(0, 0, self.width, self.height)];
            
            // Populate the RMFace object
            face.identifier = 1;
            face.timeTracked = CACurrentMediaTime() - self.timeFirstSeen;
            face.boundingBox = faceRect;
            
            face.location = CGPointMake(CGRectGetMidX(faceRect) * -1,
                                        CGRectGetMidY(faceRect) * -1);
            face.distance = [RMImageUtils estimateDistance:faceRect];
            face.advancedInfo = NO;
            face.frameNumber = self.frameNumber;
            
            // Only if we have a fresh frame
            if (self.eyeDetectionEnabled) {
                [self detectEyesInFrame:faceRect withFace:face];
            } else {
                face.eyeInfo = NO;
            }
            
            // Put it on the main queue!
            dispatch_async(dispatch_get_main_queue(), ^(void){
                // Create new timer
                self.resetTimer = [NSTimer scheduledTimerWithTimeInterval:self.timeout
                                                                   target:self
                                                                 selector:@selector(didLoseFace)
                                                                 userInfo:nil
                                                                  repeats:NO];
                [self faceDetected:face];
            });
        }
    }
}

// Results from the face detection (AVCaptureMetadataOutputObjectsDelegate)
//------------------------------------------------------------------------------
- (void)   captureOutput:(AVCaptureOutput *)captureOutput
didOutputMetadataObjects:(NSArray *)metadataObjects
          fromConnection:(AVCaptureConnection *)c
{
    for ( AVMetadataObject *object in metadataObjects ) {
        if ( [[object type] isEqual:AVMetadataObjectTypeFace] ) {
            // Create a new face object
            RMFace *newState = [[RMFace alloc] init];
            
            if (!self.trackingFace) {
                self.trackingFace = YES;
                self.timeFirstSeen = CACurrentMediaTime();
                newState.justFound = YES;
            } else {
                newState.justFound = NO;
            }
            
            // Invalidate the timer
            [self.resetTimer invalidate];
            
            // Get face object and pull out data
            AVMetadataFaceObject* face = (AVMetadataFaceObject*)object;
            CGRect faceRect = [face bounds];
            NSInteger faceID = [face faceID];
            CGFloat rollAngle = [face rollAngle] - kAVCaptureRollOffset;
            CGFloat yawAngle = [face yawAngle];
            
            // Convert ROI to robot coordinates
            CGRect robotFaceRect = [RMImageUtils normalizeAVMetadata:faceRect];
            
            // Populate the RMFace object
            newState.identifier = faceID;
            newState.timeTracked = CACurrentMediaTime() - self.timeFirstSeen;
            newState.boundingBox = robotFaceRect;
            
            newState.location = CGPointMake(CGRectGetMidX(robotFaceRect) * -1,
                                            CGRectGetMidY(robotFaceRect) * -1);
            newState.distance = [RMImageUtils estimateDistance:robotFaceRect];
            newState.boundingBox = robotFaceRect;
            
            newState.advancedInfo = YES;
            newState.rotation = rollAngle;
            newState.profileAngle = yawAngle;
            
            // Only if we have a fresh frame
            if (self.eyeDetectionEnabled && self.frameProcessed) {
                [self detectEyesInFrame:robotFaceRect withFace:newState];
                
                // Reset frame processed flag
                self.frameProcessed = NO;
            } else {
                newState.eyeInfo = NO;
            }
            // Restart timer
            self.resetTimer = [NSTimer scheduledTimerWithTimeInterval:self.timeout
                                                               target:self
                                                             selector:@selector(didLoseFace)
                                                             userInfo:nil
                                                              repeats:NO];
            
            // Send off results
            [self faceDetected:newState];
        }
    }
}

#pragma mark - Delegators

// Delegates a detected face in robot coordinates
//------------------------------------------------------------------------------
- (void)faceDetected:(RMFace *)face
{
    self.curFocus = face.location;
    self.numFaces = 1;
    
    if ([self.vision.delegate respondsToSelector:@selector(didDetectFace:)]) {
        [self.vision.delegate didDetectFace:face];
    }
}

// Indicatres the face was lost (not seen within the timeout)
//------------------------------------------------------------------------------
- (void)didLoseFace
{
    self.trackingFace = NO;
    self.numFaces = 0;
    
    [self.resetTimer invalidate];
    if ([self.vision.delegate respondsToSelector:@selector(didLoseFace)]) {
        [self.vision.delegate didLoseFace];
    }
}

#pragma mark - Eye Detection

// Setter for eye detection
//------------------------------------------------------------------------------
- (void)setEyeDetectionEnabled:(BOOL)eyeDetectionEnabled
{
    if (eyeDetectionEnabled != _eyeDetectionEnabled) {
        if (eyeDetectionEnabled) {
            // Load eye cascades
            NSString* mainBundlePath = [[NSBundle mainBundle] resourcePath];
            NSString* frameworkBundlePath = [mainBundlePath stringByAppendingPathComponent:@"RMVision.bundle"];
            NSBundle* visionBundle = [NSBundle bundleWithPath:frameworkBundlePath];
            
            NSString *eyeCascadePath = [visionBundle pathForResource:kEyeCascadePath ofType:@"xml"];
            if (!self.eyeCascade.load([eyeCascadePath UTF8String])) {
                NSLog(@"Could not load cascade: %@", eyeCascadePath);
            }
        }
        _eyeDetectionEnabled = eyeDetectionEnabled;
    }
}

// Runs eye detectors
//------------------------------------------------------------------------------
- (void)detectEyesInFrame:(CGRect)robotFaceRect
                 withFace:(RMFace *)face
{
    CGRect cvFaceRect = [RMImageUtils frameObject:robotFaceRect
                                     withinBounds:CGRectMake(0, 0, self.output.cols, self.output.rows)];
    
    cv::Mat temp = self.output;
    temp = temp(cv::Rect(cvFaceRect.origin.x, cvFaceRect.origin.y, cvFaceRect.size.width, cvFaceRect.size.height));
    
    // Calculate ROI for eye detectors
    float leftOffset = cvFaceRect.size.width * .1;
    float topOffset = cvFaceRect.size.height * .15;
    cv::Rect leftEyeRect = cv::Rect(leftOffset,
                                    topOffset,
                                    (cvFaceRect.size.width/2) - (leftOffset/2),
                                    (cvFaceRect.size.height/2.5));
    
    cv::Rect rightEyeRect = cv::Rect((cvFaceRect.size.width/2) - (leftOffset/2),
                                     topOffset,
                                     (cvFaceRect.size.width/2) - (leftOffset/2),
                                     (cvFaceRect.size.height/2.5));
    
    // Create matrices with desired ROI for eye detectors
    cv::Mat leftEyeRegion = temp(leftEyeRect);
    cv::Mat rightEyeRegion = temp(rightEyeRect);
    
    // Run the eye detectors
    BOOL lEyeVisible = [self detectEye:leftEyeRegion];
    BOOL rEyeVisible = [self detectEye:rightEyeRegion];
    
    face.eyeInfo = YES;
    face.leftEyeOpen = lEyeVisible;
    face.rightEyeOpen = rEyeVisible;
}

// Detects eyes
//------------------------------------------------------------------------------
- (BOOL)detectEye:(cv::Mat &)faceRegion
{
    std::vector<cv::Rect> eyes;
    
    self.eyeCascade.detectMultiScale(faceRegion, eyes, 1.1, 3, kHaarOptions, cv::Size(15, 15));
    
    return eyes.size();
}

@end
