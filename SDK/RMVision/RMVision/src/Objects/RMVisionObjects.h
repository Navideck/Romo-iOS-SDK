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
//  RMVisionObject.h
//      Contains definitions for all types recognizable by the vision system
//  Romo3
//
//  Created by Romotive on 5/1/13.
//  Copyright (c) 2013 Romotive. All rights reserved.
//
////////////////////////////////////////////////////////////////////////////////
#ifndef Romo3_RMVisionObjects_h
#define Romo3_RMVisionObjects_h

#import <CoreGraphics/CoreGraphics.h>
#import <UIKit/UIKit.h>

// RMObject
//      Base type for objects
//==============================================================================
@interface RMObject : NSObject <NSCoding>

@property (nonatomic)   int     identifier;
@property (nonatomic)   CGFloat timeTracked;
@property (nonatomic)   CGRect  boundingBox;
@property (nonatomic)   BOOL    justFound;
@property (nonatomic) uint32_t frameNumber;

//@property (nonatomic)   RMPoint3D loc3D;
//@property (nonatomic)   NSString *name;

-(NSDictionary *)convertToNSDictionary;
-(id)initWithDictionary:(NSDictionary *)dictionary;
-(BOOL)isApproximatelyEqual:(RMObject *)other withTolerance:(float)tolerance;

@end

// RMFace
//      Type containing information about a face
//==============================================================================
@interface RMFace : RMObject

// Required
@property (nonatomic) CGPoint location;
@property (nonatomic) CGFloat distance;
@property (nonatomic) BOOL    advancedInfo;
@property (nonatomic) BOOL    eyeInfo;

// Optional
@property (nonatomic) CGFloat rotation;
@property (nonatomic) CGFloat profileAngle;

@property (nonatomic) BOOL    leftEyeOpen;
@property (nonatomic) BOOL    rightEyeOpen;

@end

// RMBlob
//      Type for reasoning about blobs
//==============================================================================
@interface RMBlob : RMObject

// Required
@property (nonatomic)   CGPoint centroid;
@property (nonatomic)   CGFloat area;
@property (nonatomic)   NSArray *path;
@property (nonatomic)   BOOL    isColorBlob;

// Optional
@property (nonatomic)   CGColorRef color;

-(NSDictionary *)convertToNSDictionary;
-(id)initWithDictionary:(NSDictionary *)dictionary;
-(BOOL)isApproximatelyEqual:(RMBlob *)other withTolerance:(float)tolerance;

@end

// RMMotion
//      Type for reasoning about motion
//==============================================================================
@interface RMMotion : RMObject

// Required
@property (nonatomic)   CGPoint centroid;
@property (nonatomic)   CGFloat area;
@property (nonatomic)   BOOL    hasMoment;

// Optional
//@property (nonatomic)   RMPoint3D moment;

@end

// RMLine
//      Type for reasoning about a line
//==============================================================================
@interface RMLine : RMObject

// Required
@property (nonatomic)   CGPoint centroid;
@property (nonatomic)   CGPoint lastSeenCentroid;
@property (nonatomic)   CGFloat area;

@end

// RMColors
//      Type for reasoning about color detection
//==============================================================================
@interface RMColors : RMObject

// Required

// Key: Color index
// Value: Percent of image that the color is occupying. Note that all the values
// will not add up to 1.0.
@property (nonatomic) NSMutableDictionary *visableColors;

// Optional

@end


// RMVisionTrainingData
//      Type for reasoning about color detection
//==============================================================================
@interface RMVisionTrainingData : RMObject <NSCopying>

// Required
#ifdef __cplusplus
@property (nonatomic) cv::Mat trainingData;
@property (nonatomic) cv::Mat labels;
#endif

@property (nonatomic) int positiveResponseLabel;
@property (nonatomic) int negativeResponseLabel;

@property (nonatomic) float covarianceScaling;



// Methods

#ifdef __cplusplus
-(id)initWithPositivePixels:(cv::Mat)positivePixels withNegativePixels:(cv::Mat)negativePixels;
#endif

-(id)initWithPositiveImage:(UIImage *)positiveImage withNegativeExamplesImage:(UIImage *)negativeImage;
-(id)initWithCoder:(NSCoder *)aDecoder;
-(id)initRandomTestData;
-(void)encodeWithCoder:(NSCoder *)aCoder;
- (BOOL)isEqual:(id)object;

@end


#endif
