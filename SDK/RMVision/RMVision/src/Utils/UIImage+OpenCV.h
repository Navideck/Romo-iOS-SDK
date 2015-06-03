////////////////////////////////////////////////////////////////////////////////
//                             _
//                            | | (_)
//   _ __ ___  _ __ ___   ___ | |_ ___   _____
//  | '__/ _ \| '_ ` _ \ / _ \| __| \ \ / / _ \
//  | | | (_) | | | | | | (_) | |_| |\ V /  __/
//  |_|  \___/|_| |_| |_|\___/ \__|_| \_/ \___|
//
////////////////////////////////////////////////////////////////////////////////
//
//  UIImage+OpenCV.h
//      Category for extending the UIImage class with OpenCV 2.0 support
//  RMVision
//
//  Created on 10/26/12.
//  Copyright (c) 2012 Romotive. All rights reserved.
//
////////////////////////////////////////////////////////////////////////////////
#import <CoreVideo/CoreVideo.h>
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#import <opencv2/core/types_c.h>

@interface UIImage (UIImage_OpenCV)

// cv::Mat utilities
//==============================================================================
@property(nonatomic, readonly) cv::Mat CVMat;
@property(nonatomic, readonly) cv::Mat CVGrayscaleMat;

+(UIImage *)imageWithCVMat:(const cv::Mat&)cvMat;
+(UIImage *)imageWithCVMat:(const cv::Mat&)cvMat scale:(CGFloat)scale orientation:(UIImageOrientation)orientation;
-(id)initWithCVMat:(const cv::Mat&)other;
-(id)initWithCVMat:(const cv::Mat&)other scale:(CGFloat)scale orientation:(UIImageOrientation)orientation;
+ (cv::Mat)cvMatWithImage:(UIImage *)image;

// IplImage utilities
//==============================================================================
// These DO copy the image data out of the UIImage.  It's safe to
// deallocate the UIImage and continue to use the IplImage.
//------------------------------------------------------------------------------
+ (IplImage *)createGRAYIplImageFromUIImage:(UIImage *)image;
+ (IplImage *)createBGRAIplImageFromUIImage:(UIImage *)image;

// these DO NOT copy the underlying data (for speed), do don't deallocate
// the underlying data (usually the IplImage itself) until you're done with
// the UIImage!
//------------------------------------------------------------------------------
+ (UIImage *)UIImageFromBGRIplImage:(IplImage *)bgrImage;
+ (UIImage *)UIImageFromRGBIplImage:(IplImage *)bgrImage;
+ (UIImage *)UIImageFromBGRAIplImage:(IplImage *)bgraImage;
+ (UIImage *)UIImageFromGRAYIplImage:(IplImage *)grayImage;

@end

//  Originally created by Robin Summerhill on 02/09/2011
//      (Modified by Adam Setapen on 10/31/2012)
//  Copyright 2011 Aptogo Limited. All rights reserved.
//
//  Permission is given to use this source code file without charge in any
//  project, commercial or otherwise, entirely at your risk, with the condition
//  that any redistribution (in part or whole) of source code must retain
//  this copyright and permission notice. Attribution in compiled projects is
//  appreciated but not required.
