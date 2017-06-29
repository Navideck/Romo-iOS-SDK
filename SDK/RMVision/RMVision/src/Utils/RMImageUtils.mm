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
//  RMImageUtils.mm
//  RMVision
//
//  Created on 11/9/12.
//  Copyright (c) 2012 Romotive. All rights reserved.
//
////////////////////////////////////////////////////////////////////////////////

#import "RMImageUtils.h"

#define CLAMP(min, val, max) (MAX(min, MIN(val, max)))

#define kFaceMinDist 15.0
#define kFaceMaxDist 125.0

#define FACE_MAX_DIST

static UIImage *pic;

@implementation RMImageUtils

+ (void) pathToImageView:(NSString *)picPath withBlock:(void (^)(UIImage *))block
{
    NSOperationQueue *picQueue = [[NSOperationQueue alloc] init];
    
    NSURL *picUrl = [NSURL URLWithString:picPath];
    
    NSURLRequest *urlRequest = [NSURLRequest requestWithURL:picUrl
                                                              cachePolicy:NSURLRequestUseProtocolCachePolicy
                                                          timeoutInterval:10.0f];
    
    [NSURLConnection sendAsynchronousRequest:urlRequest
                                       queue:picQueue
                           completionHandler:^(NSURLResponse *response,
                                               NSData *data,
                                               NSError *error)
     {
         if (error) {
             NSLog(@"Error while getting profile picture: %@", error);
             return;
         }
         
         if (!data) {
             NSLog(@"No data returned when getting profile picture");
             return;
         }

         pic = [UIImage imageWithData:data];
         
         dispatch_sync(dispatch_get_main_queue(), ^{
             block(pic);
         });
     }];
}

// Save a cv::Mat image to file as a Bitmap in the Documents-Directory
//  with a given filename
//------------------------------------------------------------------------------
+ (BOOL)saveImage:(cv::Mat &)image
     withFilename:(NSString *)filename
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,
                                                         NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    NSString *filePath = [documentsDirectory stringByAppendingPathComponent:
                          [NSString stringWithFormat:@"%@.bmp", filename]];
    const char* cPath = [filePath cStringUsingEncoding:NSMacOSRomanStringEncoding];
    
    const cv::String newPaths = (const cv::String)cPath;
    
    //
    return cv::imwrite(newPaths, image);
}

//------------------------------------------------------------------------------
+ (CGRect) normalizeObject:(CGRect)object
               withinFrame:(CGRect)frame
{
    return CGRectMake(
        [self normalizePoint:object.origin.x withinBounds:frame.size.width],
        [self normalizePoint:object.origin.y withinBounds:frame.size.height],
        [self normalizePixels:object.size.width withinBounds:frame.size.width],
        [self normalizePixels:object.size.height withinBounds:frame.size.height]);
}

//------------------------------------------------------------------------------
+ (float)normalizePoint:(int)point
           withinBounds:(int)bounds
{
    return (point / (bounds/2.0)) - 1.0;
}

//------------------------------------------------------------------------------
+ (float)normalizePixels:(int)pixels
            withinBounds:(int)bounds
{
    
    return (((float)pixels) / bounds) * 2.0;
}

//------------------------------------------------------------------------------
+ (CGRect) frameObject:(CGRect)object
          withinBounds:(CGRect)frame
{
    uint32_t originX = CLAMP(frame.origin.x,
                             [self framePoint:object.origin.x withinBounds:frame.size.width],
                             frame.size.width);
    uint32_t originY = CLAMP(frame.origin.y,
                             [self framePoint:object.origin.y withinBounds:frame.size.height],
                             frame.size.height);
    
    return CGRectMake(
        originX,
        originY,
        CLAMP(1, [self frameSize:object.size.width withinBounds:frame.size.width], (frame.size.width - originX)),
        CLAMP(1, [self frameSize:object.size.height withinBounds:frame.size.height], (frame.size.height - originY )) );
}

//------------------------------------------------------------------------------
+ (CGRect) normalizeAVMetadata:(CGRect)object
{
    return CGRectMake(
                      (object.origin.y * 2.0) - 1.0,
                      (object.origin.x * 2.0) - 1.0,
                      (object.size.height * 2.0),
                      (object.size.width * 2.0));
}

//------------------------------------------------------------------------------
+ (CGPoint)locationOfObject:(CGPoint)object
                withinFrame:(CGSize)frame
{
    return CGPointMake(
                       [self framePoint:object.x withinBounds:frame.width],
                       [self framePoint:object.y withinBounds:frame.height]);
}

//------------------------------------------------------------------------------
+ (float)normalize:(int)point
      withinBounds:(int)bounds
{
    return (point / (bounds/2.0)) - 1.0;
}

//------------------------------------------------------------------------------
+ (int)framePoint:(float)point
     withinBounds:(float)bounds
{
    return (point + 1.0) * (bounds/2.0);
}

//------------------------------------------------------------------------------
+ (int)frameSize:(float)size
    withinBounds:(float)bounds
{
    return size * (bounds/2.0);
}

//------------------------------------------------------------------------------
+ (CGPoint) pixelsToRobotFrame:(CGRect)obj
{
    //    NSLog(@"Object @ : %@", NSStringFromCGRect(_vision.view.bounds));
    float xMax = 133;
    float x = obj.origin.x + (obj.size.width / 2);
    if (x > xMax) {
        x = xMax;
    }
    x = ((x - (xMax / 2)) * -1) / (xMax/2);
    
    float yMax = 163;
    float y = obj.origin.y + (obj.size.height / 2);
    if (y > yMax) {
        y = yMax;
    }
    y = ((y - (yMax / 2)) * -1) / (yMax/2);
    
    return CGPointMake(x, y);
}

// Estimates the distance of a bounding box in centimeters
//------------------------------------------------------------------------------
+ (CGFloat)estimateDistance:(CGRect)boundingBox
{
    float rawSize = boundingBox.size.height * boundingBox.size.width;
    CGFloat scaled = (-25.496 * log(rawSize)) + 35.608;
    return CLAMP(kFaceMinDist, scaled, kFaceMaxDist);
}

// Euclidian distance between two points
//------------------------------------------------------------------------------
+ (float)distanceBetween:(CGPoint)point1
                andPoint:(CGPoint)point2
{
    float dx = (point2.x - point1.x);
    float dy = (point2.y - point1.y);
    return sqrt(dx*dx + dy*dy);
}

// Rescale an input UIImage given a CGSize
//------------------------------------------------------------------------------
+ (UIImage*)imageWithImage:(UIImage*)image
              scaledToSize:(CGSize)newSize
{
    UIGraphicsBeginImageContext( newSize );
    [image drawInRect:CGRectMake(0,0,newSize.width,newSize.height)];
    UIImage* newImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return newImage;
}

//------------------------------------------------------------------------------
+ (BOOL)isCGPoint:(CGPoint)first approximatelyEqualToCGPoint:(CGPoint)second withTolerance:(float)tolerance
{
    return (fabs(first.x - second.x) < tolerance) && (fabs(first.y - second.y) < tolerance);
}

//------------------------------------------------------------------------------
+ (BOOL)isCGSize:(CGSize)first approximatelyEqualToCGSize:(CGSize)second withTolerance:(float)tolerance
{
    return (fabs(first.width - second.width) < tolerance) && (fabs(first.height - second.height) < tolerance);
}

//------------------------------------------------------------------------------
+ (BOOL)isCGRect:(CGRect)first approximatelyEqualToCGRect:(CGRect)second withTolerance:(float)tolerance
{
    return ([self isCGPoint:first.origin approximatelyEqualToCGPoint:second.origin withTolerance:tolerance] &&
            [self isCGSize:first.size approximatelyEqualToCGSize:second.size withTolerance:tolerance]);
}

@end
