//
//  GPUImageNormalBayesFilter.m
//  GPUImage
//
//  Created on 9/4/13.
//

#import "GPUImageNormalBayesFilter.h"
#import "GPUImageFilter+RMAdditions.h"

#if TARGET_IPHONE_SIMULATOR || TARGET_OS_IPHONE
NSString *const kGPUImageNormalBayesFragmentShaderString = SHADER_STRING
(
 precision highp float;
 
 varying highp vec2 textureCoordinate;
 uniform sampler2D inputImageTexture;
 
 uniform highp vec3 muA;
 uniform highp mat3 invCovarianceA;
 uniform highp vec3 muB;
 uniform highp mat3 invCovarianceB;
 
 uniform highp vec3 logDetCovar;
 
 uniform int numberOfClasses;
 
 uniform highp vec3 lastCoordinate;
 uniform highp float adaptiveFloorValue;


 float calcGaussianProb(highp vec3 sample, highp vec3 mu, highp mat3 invCovariance, float logDetCovar)
 {
     highp vec3 diff = sample - mu;
     
     float upper = dot(diff*invCovariance,diff);
     float lower = logDetCovar;
     
     float result = lower + upper;

     return result;
 }
 
 void main()
 {
     highp vec4 textureColor = texture2D(inputImageTexture, textureCoordinate);
     
     // Negative log likelihood for each class
     highp vec3 BGR = textureColor.bgr * 255.0;
     float probA =  calcGaussianProb(BGR, muA, invCovarianceA, logDetCovar[0]);
     float probB =  calcGaussianProb(BGR, muB, invCovarianceB, logDetCovar[1]);

     
// Class B is the one that we want to track
     highp vec4 outputColor;
     if (probA < probB)
     {
         outputColor = vec4(0.0);
     }
     else
     {
         outputColor = vec4(textureCoordinate, 0.0, 1.0); // Setting 1.0 in the alpha tells the position averager give weight to this pixel
         
         // Weight the centroid based on the last seen position
//         float dist = distance(textureCoordinate, lastCoordinate.xy);
//         float z = max(exp(-dist*16.0), adaptiveFloorValue);
//         outputColor = vec4(textureCoordinate*z, vec2(0.0, z));
         
     }
     
     gl_FragColor = outputColor;
 }
 );
#else

// TODO: Define fragment shader for OSX

#endif

@implementation GPUImageNormalBayesFilter

#pragma mark -
#pragma mark Initialization and teardown

- (id)init
{
    if (!(self = [super initWithFragmentShaderFromString:kGPUImageNormalBayesFragmentShaderString]))
    {
        return nil;
    }
    
    self.muA            = (GPUVector3)      { 255.0*0.7f, 255.0*0.7f, 255.0*0.7f };
    self.invCovarianceA = (GPUMatrix3x3){   { 1.0/2.55f, 0.00f, 0.00f },
                                            { 0.00f, 1.0/2.55f, 0.00f },
                                            { 0.00f, 0.00f, 1.0/2.55f }};
    
    self.muB            = (GPUVector3)      { 127.0f, 127.0f, 127.0f };
    self.invCovarianceB = (GPUMatrix3x3){   { 1.0/76.5f, 0.00f, 0.00f },
                                            { 0.00f, 1.0/76.5f, 0.00f },
                                            { 0.00f, 0.00f, 1.0/76.5f }};
    
    self.logDetCovar    = (GPUVector3)      { 2.808f, 13.012f, 0.0f};

    return self;
}

- (id)initWithModel:(NormalBayesModel *)model
{
    if (!(self = [super initWithFragmentShaderFromString:kGPUImageNormalBayesFragmentShaderString]))
    {
        return nil;
    }
    
    [self setModel:model];

    return self;
}

#pragma mark -
#pragma mark Accessors


- (void)setModel:(NormalBayesModel *)model
{
    _model = model;
    
    self.muA = model.muA;
    self.muB = model.muB;
    self.invCovarianceA = model.invCovarianceA;
    self.invCovarianceB = model.invCovarianceB;
    self.logDetCovar = model.logDetCovar;
    
    self.originalInvCovarianceB = model.invCovarianceB;
}


-(void)setMuA:(GPUVector3)muA
{
    _muA = muA;
    [self setFloatVec3:muA forUniformName:@"muA"];
}

-(void)setMuB:(GPUVector3)muB
{
    _muB = muB;
    [self setFloatVec3:muB forUniformName:@"muB"];
}

-(void)setInvCovarianceA:(GPUMatrix3x3)invCovarianceA
{
    _invCovarianceA = invCovarianceA;
    [self setMatrix3f:invCovarianceA
           forUniform:[filterProgram uniformIndex:@"invCovarianceA"]
              program:filterProgram];
}

-(void)setInvCovarianceB:(GPUMatrix3x3)invCovarianceB
{
    _invCovarianceB = invCovarianceB;
    [self setMatrix3f:invCovarianceB
           forUniform:[filterProgram uniformIndex:@"invCovarianceB"]
              program:filterProgram];
}

-(void)setLogDetCovar:(GPUVector3)logDetCovar
{
    _logDetCovar = logDetCovar;
    [self setFloatVec3:logDetCovar forUniformName:@"logDetCovar"];
}

-(void)scaleCovarianceBy:(float)scale
{
    if (scale > 0) {
        float inv_scale = 1.0/scale;
        self.invCovarianceB = [GPUImageFilter multiplyGPUMatrix3x3:self.originalInvCovarianceB byScaler:inv_scale];
    }
}

@end

@implementation NormalBayesModel

@end
