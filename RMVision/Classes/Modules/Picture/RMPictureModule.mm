//
//  RMPictureModule.m
//  RMVision
//
//  Created on 6/24/13.
//  Copyright (c) 2013 Romotive, Inc. All rights reserved.
//

#import "RMPictureModule.h"
#import "UIImage+OpenCV.h"

NSString *const RMPictureModuleDidTakePictureNotification = @"RMPictureModuleDidTakePictureNotification";

@interface RMPictureModule ()

@property (nonatomic, strong) AVCaptureStillImageOutput *captureImageOutput;

@end

@implementation RMPictureModule

-(id)initWithVision:(RMVision *)core
{
    return [super initModule:RMVisionModule_TakePicture
                  withVision:core];
}

-(void)shutdown
{
    [super shutdown];
}

-(void)processFrame:(const cv::Mat)mat
          videoRect:(CGRect)rect
   videoOrientation:(AVCaptureVideoOrientation)videoOrientation
{
    // Normally you should call super processFrame here, but this is a special case.
    
    // Save image and post a notification
    UIImage *imageToSave;
    
    if (self.vision.isImageFlipped) {
        imageToSave = [UIImage imageWithCVMat:mat scale:1.0 orientation:UIImageOrientationUpMirrored];
    } else {
        imageToSave = [UIImage imageWithCVMat:mat scale:1.0 orientation:UIImageOrientationUp];
    }
    
    UIImageWriteToSavedPhotosAlbum(imageToSave, nil, nil, nil);
    [self.vision deactivateModuleWithName:self.name];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:RMPictureModuleDidTakePictureNotification
                                                        object:self.vision
                                                      userInfo:@{@"photo" : imageToSave}];
}

@end
