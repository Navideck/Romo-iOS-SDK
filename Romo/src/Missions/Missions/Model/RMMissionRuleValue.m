//
//  RMMissionRuleValue.m
//  Romo
//

#import "RMMissionRuleValue.h"
#import "RMParameter.h"

@interface RMMissionRuleValue ()

@property (nonatomic, readwrite) RMParameterType parameterType;
@property (nonatomic, readwrite) int index;

@end

@implementation RMMissionRuleValue

- (id)initWithDictionary:(NSDictionary *)dictionary
{
    self = [super init];
    if (self) {
        NSString *parameterName = dictionary[@"parameterName"];
        RMParameterType parameterType = [[RMParameter alloc] initFromString:parameterName].type;

        if (dictionary[@"index"]) {
            NSNumber *index = dictionary[@"index"];
            self.parameterType = parameterType;
            self.index = index.intValue;
        } else {
            self.parameterType = parameterType;
            self.index = -1;
        }
    }
    return self;
}

+ (instancetype)valueWithParameterType:(RMParameterType)parameterType
{
    return [self valueWithParameterType:parameterType forActionAtIndex:-1];
}

+ (instancetype)valueWithParameterType:(RMParameterType)parameterType forActionAtIndex:(int)index
{
    RMMissionRuleValue *value = [[RMMissionRuleValue alloc] init];
    if (value) {
        value.parameterType = parameterType;
        value.index = index;
    }
    return value;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"Param%d%@",self.parameterType,
            self.index >= 0 ? [NSString stringWithFormat:@"[%d]",self.index] : @""];
}

@end
