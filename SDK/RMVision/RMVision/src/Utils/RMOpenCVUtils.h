//
//  RMOpenCVUtils.h
//  RMVision
//
//  Created on 10/22/13.
//  Copyright (c) 2013 Romotive, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface RMOpenCVUtils : NSObject

+(cv::Mat)extractRowsFromVectorizedMat:(const cv::Mat)mat withMask:(const cv::Mat)mask;

+ (void)convertImage:(const cv::Mat)image
       toImageVector:(cv::Mat &)imageVector
            withMask:(const cv::Mat)mask;

bool matIsEqual(const cv::Mat mat1, const cv::Mat mat2);

@end
