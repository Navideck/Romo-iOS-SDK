//
//  GPUImageNaiveBayesFilter.h
//  GPUImage
//
//  Created on 9/4/13.
//

#import "GPUImageFilter.h"

@interface NormalBayesModel : NSObject

@property(nonatomic) GPUVector3 muA;
@property(nonatomic) GPUVector3 muB;

@property(nonatomic) GPUMatrix3x3 invCovarianceA;
@property(nonatomic) GPUMatrix3x3 invCovarianceB;

@property(nonatomic) GPUVector3 logDetCovar;

@end


@interface GPUImageNormalBayesFilter : GPUImageFilter
{
}

@property(nonatomic) GPUVector3 muA;
@property(nonatomic) GPUVector3 muB;

@property(nonatomic) GPUMatrix3x3 invCovarianceA;
@property(nonatomic) GPUMatrix3x3 invCovarianceB;

@property(nonatomic) GPUMatrix3x3 originalInvCovarianceB;


@property(nonatomic) GPUVector3 logDetCovar;

@property(nonatomic) NormalBayesModel *model;


- (id)init;
- (id)initWithModel:(NormalBayesModel *)model;

- (void)scaleCovarianceBy:(float)scale;



@end
