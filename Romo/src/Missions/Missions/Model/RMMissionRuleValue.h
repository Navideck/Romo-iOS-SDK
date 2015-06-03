//
//  RMMissionRuleValue.h
//  Romo
//

#import <Foundation/Foundation.h>
#import "RMParameter.h"

@interface RMMissionRuleValue : NSObject

@property (nonatomic, readonly) RMParameterType parameterType;
@property (nonatomic, readonly) int index;

- (id)initWithDictionary:(NSDictionary *)dictionary;

@end
