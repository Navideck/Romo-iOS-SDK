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
//  RMImageUtils.h
//  RMVision
//
//  Created on 11/9/12.
//  Copyright (c) 2012 Romotive. All rights reserved.
//
////////////////////////////////////////////////////////////////////////////////
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#define PrintFrame(frame) NSLog(@"%@", NSStringFromCGRect(frame));

@interface RMImageUtils : NSObject

+ (void) pathToImageView:(NSString *)picPath
               withBlock:(void (^)(UIImage *))block;

+ (CGPoint) pixelsToRobotFrame:(CGRect) obj;

+ (CGRect) normalizeObject:(CGRect)object
               withinFrame:(CGRect)frame;

+ (CGPoint)locationOfObject:(CGPoint)object
                withinFrame:(CGSize)frame;

+ (CGRect) frameObject:(CGRect)object
          withinBounds:(CGRect)frame;

+ (CGRect) normalizeAVMetadata:(CGRect)object;
+ (CGFloat) estimateDistance:(CGRect)boundingBox;

+ (float)distanceBetween:(CGPoint)point1
                andPoint:(CGPoint)point2;

+ (float)normalizePoint:(int)point
           withinBounds:(int)bounds;

+ (UIImage*)imageWithImage:(UIImage*)image
              scaledToSize:(CGSize)newSize;


+ (BOOL)isCGPoint:(CGPoint)first approximatelyEqualToCGPoint:(CGPoint)second withTolerance:(float)tolerance;
+ (BOOL)isCGSize:(CGSize)first approximatelyEqualToCGSize:(CGSize)second withTolerance:(float)tolerance;
+ (BOOL)isCGRect:(CGRect)first approximatelyEqualToCGRect:(CGRect)second withTolerance:(float)tolerance;
@end
