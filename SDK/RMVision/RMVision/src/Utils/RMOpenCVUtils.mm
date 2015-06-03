//
//  RMOpenCVUtils.m
//  RMVision
//
//  Created on 10/22/13.
//  Copyright (c) 2013 Romotive, Inc. All rights reserved.
//

#import "RMOpenCVUtils.h"

@implementation RMOpenCVUtils

//------------------------------------------------------------------------------
+ (cv::Mat)extractRowsFromVectorizedMat:(const cv::Mat)mat withMask:(const cv::Mat)mask
{
    
    int nonZeroCount = cv::countNonZero(mask);
    cv::Mat output(nonZeroCount, mat.cols, mat.type());
    
    
    size_t outputRow = 0;
    for (size_t i = 0; i < mat.rows; i++)
    {
        if (mask.at<uchar>(i)) {
            mat.row(i).copyTo(output.row(outputRow));
            outputRow++;
        }
    }
    
    return output;
}


//------------------------------------------------------------------------------
/// Converts a 2D multiple channel image to a matrix with each pixel on a row
/**
 Converts a 2D multiple channel image to a n-by-c matrix with n pixels in the 
 original image and c channels in the original image.
 @param image A 2D multiple channel image to convert
 @param imageVector The output matrix from the conversion
 @param mask An input mask to specify which pixels to vectorize. An empty input
 mask (cv::Mat()) will vectorize every pixel in the original matrix.
 */
+ (void)convertImage:(const cv::Mat)image
       toImageVector:(cv::Mat &)imageVector
            withMask:(const cv::Mat)mask
{
    cv::Mat localMask = mask.clone();
    if (mask.empty()) {
        localMask = cv::Mat(image.size(), CV_8UC1, cv::Scalar(255));
    }
    
    if (localMask.channels() != 1) {
        NSLog(@"Mask must be binary image. Number of channels is: %d", localMask.channels());
        assert(localMask.channels() == 1);
    }

    size_t totalPixels = image.rows * image.cols;
    cv::Mat tmp = image.reshape(1, totalPixels);
    cv::Mat maskVector = localMask.reshape(1, localMask.rows*localMask.cols);
    
    size_t nonZeroCount = cv::countNonZero(maskVector);
    
    imageVector.create(nonZeroCount, tmp.cols, tmp.type());
    
    size_t imageVectorRow = 0;
    for (size_t i = 0; i < tmp.rows; i++) {
        if (maskVector.at<uchar>(i)) {
            tmp.row(i).copyTo(imageVector.row(imageVectorRow));
            imageVectorRow++;
        }
    }
}

bool matIsEqual(const cv::Mat mat1, const cv::Mat mat2){
    // treat two empty mat as identical as well
    if (mat1.empty() && mat2.empty()) {
        return true;
    }
    // if dimensionality of two mat is not identical, these two mat is not identical
    if (mat1.cols != mat2.cols || mat1.rows != mat2.rows || mat1.dims != mat2.dims || mat1.channels() != mat2.channels()) {
        return false;
    }
    
    std::vector<cv::Mat> layers1, layers2;
    cv::split(mat1, layers1);
    cv::split(mat2, layers2);
    
    for (int i = 0; i < mat1.channels(); i++) {
        
        cv::Mat diff;
        cv::compare(layers1[i], layers2[i], diff, cv::CMP_NE);
        int nz = cv::countNonZero(diff);
        if (nz != 0) {
            return false;
        }
    }
    
    return true;
}

@end
