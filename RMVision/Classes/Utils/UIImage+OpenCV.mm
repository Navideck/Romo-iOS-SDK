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
//  UIImage+OpenCV.mm
//      Category for extending the UIImage class with OpenCV 2.0 support
//
//  Romo3
//
//  Created on 10/26/12.
//  Copyright (c) 2012 Romotive. All rights reserved.
//
////////////////////////////////////////////////////////////////////////////////
#import "UIImage+OpenCV.h"

static CGColorSpaceRef colorSpace = NULL;
static CGColorSpaceRef gryColorSpace = NULL;

// Category Implementation
//==============================================================================
@implementation UIImage (UIImage_OpenCV)

// Initializes a cv::Mat based on the current UIImage
//------------------------------------------------------------------------------
-(cv::Mat)CVMat
{
    return [[self class] cvMatWithImage:self];
}

// Initializes a grayscale cvMat based on the current UIImage
//------------------------------------------------------------------------------
-(cv::Mat)CVGrayscaleMat
{
    return [[self class] cvMatWithImage:self];
}

#pragma mark - UIImage Utilities

// Initializes a UIImage given a cvMat
//------------------------------------------------------------------------------
+ (UIImage *)imageWithCVMat:(const cv::Mat&)cvMat
{
    return [[UIImage alloc] initWithCVMat:cvMat scale:1.0 orientation:UIImageOrientationUp];
}

+ (UIImage *)imageWithCVMat:(const cv::Mat&)cvMat scale:(CGFloat)scale orientation:(UIImageOrientation)orientation
{
    return [[UIImage alloc] initWithCVMat:cvMat scale:scale orientation:orientation];
}

// Initializes a cvMat based on the current UIImage, and returns the object
//------------------------------------------------------------------------------
- (id)initWithCVMat:(const cv::Mat&)other
{
    return [self initWithCVMat:other scale:1.0 orientation:UIImageOrientationUp];
    
}

- (id)initWithCVMat:(const cv::Mat&)other scale:(CGFloat)scale orientation:(UIImageOrientation)orientation
{
    cv::Mat cvMat;
    
    // Direct byte copying into the CGImage will only work if the data stored in the cv::Mat is continuous
    // If it is NOT, we must clone (deep copy) the matrix first to create a continuous block of image data
    if (other.isContinuous()) {
        cvMat = other;
    } else {
        cvMat = other.clone();
    }
    
    CGColorSpaceRef colorSpace;
    CGBitmapInfo bitmapInfo;
    
    switch (other.channels()) {
        case 1:
            colorSpace = CGColorSpaceCreateDeviceGray();
            bitmapInfo = (kCGBitmapAlphaInfoMask & kCGImageAlphaNone) | (kCGBitmapByteOrderMask & kCGBitmapByteOrder32Big);
            break;
        case 3:
            cv::cvtColor(other, cvMat, CV_BGR2BGRA);
            colorSpace = CGColorSpaceCreateDeviceRGB();
            bitmapInfo = (kCGBitmapAlphaInfoMask & kCGImageAlphaFirst) | (kCGBitmapByteOrderMask & kCGBitmapByteOrder32Little);
            break;
        case 4:
            colorSpace = CGColorSpaceCreateDeviceRGB();
            bitmapInfo = (kCGBitmapAlphaInfoMask & kCGImageAlphaFirst) | (kCGBitmapByteOrderMask & kCGBitmapByteOrder32Little);
            break;
        default:
            NSLog(@"Undefined channel depth");
            return nil;
            break;
    }

    NSData *data = [NSData dataWithBytes:cvMat.data length:cvMat.elemSize() * cvMat.total()];
    CGDataProviderRef provider = CGDataProviderCreateWithCFData((CFDataRef)data);
    
    CGImageRef imageRef = CGImageCreate(cvMat.cols,                                     // Width
                                        cvMat.rows,                                     // Height
                                        8,                                              // Bits per component
                                        8 * cvMat.elemSize(),                           // Bits per pixel
                                        cvMat.step[0],                                  // Bytes per row
                                        colorSpace,                                     // Colorspace
                                        bitmapInfo,                                     // Bitmap info flags
                                        provider,                                       // CGDataProviderRef
                                        NULL,                                           // Decode
                                        false,                                          // Should interpolate
                                        kCGRenderingIntentDefault);                     // Intent
    
    self = [self initWithCGImage:imageRef scale:scale orientation:orientation];

    CGImageRelease(imageRef);
    CGDataProviderRelease(provider);
    CGColorSpaceRelease(colorSpace);
    
    return self;
}

// Convert a UIImage to a cv::Mat (borrowed from https://github.com/aptogo/OpenCVForiPhone )
//------------------------------------------------------------------------------
+ (cv::Mat)cvMatWithImage:(UIImage *)image
{
    CGColorSpaceRef colorSpace = CGImageGetColorSpace(image.CGImage);
    colorSpace = CGColorSpaceRetain(colorSpace);
    
    CGColorSpaceModel colorSpaceModel = CGColorSpaceGetModel(colorSpace);
    
    CGFloat cols = image.size.width;
    CGFloat rows = image.size.height;
    
    cv::Mat cvMat;
    
    CGBitmapInfo bitmapInfo = CGImageGetBitmapInfo(image.CGImage);
    CGBitmapInfo byteOrderInfo = bitmapInfo & kCGBitmapByteOrderMask;
    
    
    if (colorSpaceModel == kCGColorSpaceModelMonochrome) {
        cvMat = cv::Mat(rows, cols, CV_8UC1); // 8 bits per component, 1 channel
    } else if (colorSpaceModel == kCGColorSpaceModelRGB) {
        cvMat = cv::Mat(rows, cols, CV_8UC4); // 8 bits per component, 4 channel
    } else {
        NSAssert(NO, @"Unsupported color space");
        CGColorSpaceRelease(colorSpace);
        return (cv::Mat());
    }
    
    CFDataRef dataFromImageDataProvider;
    dataFromImageDataProvider = CGDataProviderCopyData(CGImageGetDataProvider(image.CGImage));
    unsigned char *byteData = (unsigned char *)CFDataGetBytePtr(dataFromImageDataProvider);
    
    memcpy(cvMat.data, byteData, cols*rows*cvMat.elemSize());
    
    // Convert the grayscale image to BGRA since we have a convention that all cv::Mats are BGRA
    if (colorSpaceModel == kCGColorSpaceModelMonochrome) {
        cv::cvtColor(cvMat, cvMat, CV_GRAY2BGRA);
    } else if (colorSpaceModel == kCGColorSpaceModelRGB && [self isAlphaLast:bitmapInfo] && (byteOrderInfo == kCGBitmapByteOrderDefault || byteOrderInfo == kCGBitmapByteOrder32Big)) {
        cv::cvtColor(cvMat, cvMat, CV_RGBA2BGRA);
    } else if (colorSpaceModel == kCGColorSpaceModelRGB && ![self isAlphaLast:bitmapInfo] && byteOrderInfo == kCGBitmapByteOrder32Little) {
        // Pixel is stored as ARGB with kCGBitmapByteOrder32Little so whenwe read out the bytes we get BGRA
    } else {
        NSLog(@"Invalid color space");
        // Return an empty matrix
        cvMat = cv::Mat();
    }
    
    CGColorSpaceRelease(colorSpace);
    CFRelease(dataFromImageDataProvider);
    
    return cvMat;
}

+(BOOL)isAlphaLast:(CGBitmapInfo)bitmapInfo
{
    CGBitmapInfo alphaInfo = bitmapInfo & kCGBitmapAlphaInfoMask;
    return (alphaInfo == kCGImageAlphaPremultipliedLast || alphaInfo == kCGImageAlphaLast || alphaInfo == kCGImageAlphaNoneSkipLast);
}

#pragma mark - IplImage Utilities
//==============================================================================
+ (IplImage *)createGRAYIplImageFromUIImage:(UIImage *)image {
    // TODO: remove unnecessary copy
	IplImage *bgraImage = [[self class] createBGRAIplImageFromUIImage:image];
    IplImage *gryImage = cvCreateImage(cvGetSize(bgraImage), IPL_DEPTH_8U, 1);
    cvCvtColor(bgraImage, gryImage, CV_RGBA2GRAY);
    cvReleaseImage(&bgraImage);
    return gryImage;
}

+ (IplImage *)createBGRAIplImageFromUIImage:(UIImage *)image {
	CGImageRef imageRef = image.CGImage;
	
	if (colorSpace == NULL) {
        colorSpace = CGColorSpaceCreateDeviceRGB();
        if (colorSpace == NULL) {
            // TODO: Handle the error appropriately.
            NSLog(@"colorSpace equal to NULL!");
            return nil;
        }
    }
	IplImage *iplimage = cvCreateImage(cvSize(image.size.width, image.size.height), IPL_DEPTH_8U, 4);
	CGContextRef contextRef = CGBitmapContextCreate(iplimage->imageData, iplimage->width, iplimage->height,
													iplimage->depth, iplimage->widthStep,
													colorSpace, kCGImageAlphaPremultipliedLast|kCGBitmapByteOrderDefault);
	CGContextDrawImage(contextRef, CGRectMake(0, 0, image.size.width, image.size.height), imageRef);
	CGContextRelease(contextRef);
	
	IplImage *ret = cvCreateImage(cvGetSize(iplimage), IPL_DEPTH_8U, 4);
	cvCvtColor(iplimage, ret, CV_RGBA2BGRA);
	cvReleaseImage(&iplimage);
	return ret;
}

+(UIImage *)UIImageFromIplImage:(IplImage *)image bitmapInfo:(CGBitmapInfo)bitmapInfo
{
    if (colorSpace == NULL) {
        colorSpace = CGColorSpaceCreateDeviceRGB();
        if (colorSpace == NULL) {
            // TODO: Handle the error appropriately.
            return nil;
        }
    }
    
    CGDataProviderRef provider = CGDataProviderCreateWithData(NULL,
                                                              image->imageData,
                                                              image->imageSize,
                                                              NULL);
    
	CGImageRef imageRef = CGImageCreate(image->width, image->height,
										image->depth, image->depth * image->nChannels, image->widthStep,
										colorSpace, bitmapInfo,
										provider, NULL, false, kCGRenderingIntentDefault);
	UIImage *ret = [UIImage imageWithCGImage:imageRef];
	CGImageRelease(imageRef);
	CGDataProviderRelease(provider);
	return ret;
}

//==============================================================================
+ (UIImage *)UIImageFromRGBIplImage:(IplImage *)rgbImage;
{
    CGBitmapInfo bitmapInfo = kCGImageAlphaNone|kCGBitmapByteOrderDefault;
    return [[self class] UIImageFromIplImage:rgbImage bitmapInfo:bitmapInfo];
}

+ (UIImage *)UIImageFromBGRIplImage:(IplImage *)bgrImage
{
    CGBitmapInfo bitmapInfo = kCGImageAlphaNone|kCGBitmapByteOrder32Little;
    return [[self class] UIImageFromIplImage:bgrImage bitmapInfo:bitmapInfo];
}

+ (UIImage *)UIImageFromBGRAIplImage:(IplImage *)bgraImage
{
    CGBitmapInfo bitmapInfo = kCGImageAlphaNoneSkipFirst|kCGBitmapByteOrder32Little;
    return [[self class] UIImageFromIplImage:bgraImage bitmapInfo:bitmapInfo];
}

+ (UIImage *)UIImageFromGRAYIplImage:(IplImage *)image
{
	if (gryColorSpace == NULL) {
        gryColorSpace = CGColorSpaceCreateDeviceGray();
        if (gryColorSpace == NULL) {
            //TODO: Handle the error appropriately.
            return nil;
        }
    }
    
    CGDataProviderRef provider = CGDataProviderCreateWithData(NULL,
                                                              image->imageData,
                                                              image->imageSize,
                                                              NULL);
    
	CGImageRef imageRef = CGImageCreate(image->width, image->height,
										image->depth, image->depth * image->nChannels, image->widthStep,
										gryColorSpace, kCGImageAlphaNone,
										provider, NULL, false, kCGRenderingIntentDefault);
	UIImage *ret = [UIImage imageWithCGImage:imageRef];
	CGImageRelease(imageRef);
	CGDataProviderRelease(provider);
	return ret;
}

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
