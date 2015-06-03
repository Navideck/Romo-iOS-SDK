//
//  RMStringListInput.h
//  Romo
//

#import "RMParameterInput.h"

@interface RMListInput : RMParameterInput

/** An array of NSStrings */
@property (nonatomic, copy) NSArray *options;

@end
