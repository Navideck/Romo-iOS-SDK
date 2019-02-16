//
//  RMMissionRuleConstraint.m
//  Romo
//

#import "RMMissionRuleConstraint.h"
#import <Romo/RMCharacter.h>
#import "RMMissionRuleValue.h"
#import "RMAction.h"
#import "RMDoodle.h"

@interface RMMissionRuleConstraint ()

@property (nonatomic, readwrite, strong) id leftValue;
@property (nonatomic, readwrite, strong) id rightValue;
@property (nonatomic, readwrite) RMMissionConstraintComparisonType comparisonType;
@property (nonatomic, readwrite) BOOL needsLeftInput;
@property (nonatomic, readwrite) BOOL needsRightInput;

@end

@implementation RMMissionRuleConstraint

- (id)initWithDictionary:(NSDictionary *)dictionary
{
    self = [super init];
    if (self) {
        id leftValue = dictionary[@"leftValue"];
        if ([leftValue isKindOfClass:[NSDictionary class]]) {
            self.leftValue = [[RMMissionRuleValue alloc] initWithDictionary:leftValue];
        } else {
            self.leftValue = leftValue;
        }

        id rightValue = dictionary[@"rightValue"];
        if ([rightValue isKindOfClass:[NSDictionary class]]) {
            self.rightValue = [[RMMissionRuleValue alloc] initWithDictionary:rightValue];
        } else {
            self.rightValue = rightValue;
        }

        NSString *comparisonType = dictionary[@"comparisonType"];
        if ([comparisonType isEqualToString:@"="]) {
            self.comparisonType = '=';
        } else if ([comparisonType isEqualToString:@"<"]) {
            self.comparisonType = '<';
        } else if ([comparisonType isEqualToString:@">"]) {
            self.comparisonType = '>';
        } else if ([comparisonType isEqualToString:@"~"]) {
            self.comparisonType = '~';
        } else if ([comparisonType isEqualToString:@"!"]) {
            self.comparisonType = '!';
        }
    }
    return self;
}

- (void)setLeftValue:(id)leftValue
{
    _leftValue = leftValue;
    self.needsLeftInput = [leftValue isKindOfClass:[RMMissionRuleValue class]];
}

- (void)setRightValue:(id)rightValue
{
    _rightValue = rightValue;
    self.needsRightInput = [rightValue isKindOfClass:[RMMissionRuleValue class]];
}

- (BOOL)isValid
{
    id leftValue = nil;
    id rightValue = nil;
    RMParameterType parameterType = 0;
    
    if (self.needsLeftInput) {
        parameterType = ((RMMissionRuleValue *)self.leftValue).parameterType;
        leftValue = [self valueForParameterType:parameterType
                                     fromAction:self.leftInput];
    } else {
        leftValue = self.leftValue;
    }
    
    if (self.needsRightInput) {
        parameterType = ((RMMissionRuleValue *)self.rightValue).parameterType;
        rightValue = [self valueForParameterType:parameterType
                                      fromAction:self.rightInput];
    } else {
        rightValue = self.rightValue;
    }

    return [self compareLeftValue:leftValue rightValue:rightValue withComparisonType:self.comparisonType parameterType:parameterType];
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"[%@ %c %@]", self.leftInput ? self.leftInput : self.leftValue, self.comparisonType, self.rightInput ? self.rightInput : self.rightValue];
}

#pragma mark - Private Methods

- (BOOL)compareLeftValue:(id)leftValue
              rightValue:(id)rightValue
      withComparisonType:(RMMissionConstraintComparisonType)comparisonType
           parameterType:(RMParameterType)parameterType
{
    switch (parameterType) {
            // similar floats are within 10%
        case RMParameterDistance:
        case RMParameterSpeed:
        case RMParameterDuration:
        case RMParameterLightBrightness:
        case RMParameterRadius: {
            float leftFloat = [leftValue floatValue];
            float rightFloat = [rightValue floatValue];
            switch (comparisonType) {
                case '=': return leftFloat == rightFloat;
                case '!': return leftFloat == -rightFloat;
                case '~': return ABS(leftFloat - rightFloat) <= 0.1 * ((leftFloat + rightFloat) / 2);
                case '<': return leftFloat <= rightFloat;
                case '>': return leftFloat >= rightFloat;
            }
            break;
        }
         
            // tilt angles have custom '!' comparisons:
            // a != b ==> they are ≥ 10° apart
        case RMParameterAngle: {
            float leftFloat = [leftValue floatValue];
            float rightFloat = [rightValue floatValue];
            switch (comparisonType) {
                case '=': return leftFloat == rightFloat;
                case '!': return ABS(leftFloat - rightFloat) >= 8.0;
                case '~': return ABS(leftFloat - rightFloat) <= 0.1 * ((leftFloat + rightFloat) / 2);
                case '<': return leftFloat <= rightFloat;
                case '>': return leftFloat >= rightFloat;
            }
            break;
        }
            
            // turn directions can't be similar
        case RMParameterTurnDirection: {
            BOOL leftDirection = [leftValue boolValue];
            BOOL rightDirection = [rightValue boolValue];
            switch (comparisonType) {
                case '=': case '~': return leftDirection == rightDirection;
                case '!': return leftDirection != rightDirection;
                case '<': return leftDirection <= rightDirection;
                case '>': return leftDirection >= rightDirection;
            }
            break;
        }
            
            // emotions & expressions can't be similar
        case RMParameterExpression:
        case RMParameterEmotion: {
            BOOL leftInt = [leftValue intValue];
            BOOL rightInt = [rightValue intValue];
            switch (comparisonType) {
                case '=': return leftInt == rightInt;
                case '!': return leftInt != rightInt;
                case '<': return leftInt < rightInt;
                case '>': return leftInt > rightInt;
                case '~': {
                    return [self expression:[rightValue intValue] isSimilarToEmotion:[leftValue intValue]];
                }
            }
            break;
        }
            
            // Songs can only be equal
        case RMParameterSong: {
            return [leftValue isEqual:rightValue];
        }
            
            // Strings are similar if identical, < or > by length
        case RMParameterText: {
            switch (comparisonType) {
                case '=': case '~': return [leftValue isEqualToString:rightValue]; break;
                case '!': return NO;
                case '<': return [leftValue length] < [rightValue length]; break;
                case '>': return [leftValue length] > [rightValue length]; break;
            }
        }
            
            // Times are similar if they're < 15 min apart; less if earlier in the day
        case RMParameterTime: {
            NSRange leftDecimalRange = [leftValue rangeOfString:@":"];
            NSRange leftSpaceRange = [leftValue rangeOfString:@" "];
            int leftHours = [[leftValue substringToIndex:leftDecimalRange.location] intValue];
            int leftMinutes = [[leftValue substringWithRange:NSMakeRange(leftDecimalRange.location + 1, 2)] intValue];
            BOOL leftAM = [[leftValue substringFromIndex:leftSpaceRange.location + 1] isEqualToString:@"AM"];
            
            NSRange rightDecimalRange = [rightValue rangeOfString:@":"];
            NSRange rightSpaceRange = [rightValue rangeOfString:@" "];
            int rightHours = [[rightValue substringToIndex:rightDecimalRange.location] intValue];
            int rightMinutes = [[rightValue substringWithRange:NSMakeRange(rightDecimalRange.location + 1, 2)] intValue];
            BOOL rightAM = [[rightValue substringFromIndex:rightSpaceRange.location + 1] isEqualToString:@"AM"];
            
            // time in minutes past midnight
            int leftTime = (leftAM ? 0 : 12 * 60) + (60 * leftHours) + leftMinutes;
            int rightTime = (rightAM ? 0 : 12 * 60) + (60 * rightHours) + rightMinutes;
            
            switch (comparisonType) {
                case '=': return leftTime == rightTime;
                case '!': return NO;
                case '~': return ABS(leftTime - rightTime) < 15;
                case '<': return leftTime < rightTime;
                case '>': return leftTime > rightTime;
            }
        }
            
        case RMParameterLookPoint: {
            NSRange lcomma = [leftValue rangeOfString:@", "];
            CGFloat lx = [[leftValue substringToIndex:lcomma.location] floatValue];
            CGFloat ly = [[leftValue substringFromIndex:lcomma.location + lcomma.length] floatValue];
            NSRange rcomma = [rightValue rangeOfString:@", "];
            CGFloat rx = [[rightValue substringToIndex:rcomma.location] floatValue];
            CGFloat ry = [[rightValue substringFromIndex:rcomma.location + rcomma.length] floatValue];
            
            CGFloat lDistanceFromOrigin = sqrtf(lx*lx + ly*ly);
            CGFloat rDistanceFromOrigin = sqrtf(rx*rx + ry*ry);
            
            switch (comparisonType) {
                case '=': return (lx == rx) && (ly == ry);
                case '!': return sqrt(powf(lx - rx, 2) + powf(ly - ry, 2)) > 1.0;
                case '~': return (ABS(lx - rx) < 0.1 * ((lx + rx) / 2)) && (ABS(ly - ry) < 0.1 * ((ly + ry) / 2));
                case '<': return lDistanceFromOrigin < rDistanceFromOrigin;
                case '>': return lDistanceFromOrigin > rDistanceFromOrigin;
            }
        }
            
        case RMParameterDoodle: {
            RMDoodle *doodle = leftValue;
            int complexity = doodle.complexity;
            int desiredComplexity = [rightValue intValue];
            switch (comparisonType) {
                case '=': return complexity == desiredComplexity;
                case '!': return complexity != desiredComplexity;
                case '~': return ABS(complexity - desiredComplexity) == 1;
                case '<': return complexity < desiredComplexity;
                case '>': return complexity > desiredComplexity;
            }
        }
            
        default:
            //            switch (comparisonType) {
            //                case '=': return;
            //                case '!': return;
            //                case '~': return;
            //                case '<': return;
            //                case '>': return;
            //            }
            break;
    }
    
    if ([leftValue isKindOfClass:[NSString class]]) {
        switch (comparisonType) {
            case '=': case '~': return [leftValue isEqualToString:rightValue]; break;
            case '!': return NO;
            case '<': return [leftValue length] < [rightValue length]; break;
            case '>': return [leftValue length] > [rightValue length]; break;
        }
    } else if ([leftValue isKindOfClass:[NSNumber class]]) {
    }
    
    return NO;
}

- (BOOL)expression:(RMCharacterExpression)expression isSimilarToEmotion:(RMCharacterEmotion)emotion
{
    NSArray *matchingExpressions = nil;
    switch (emotion) {
        case RMCharacterEmotionBewildered:
        case RMCharacterEmotionIndifferent:
        case RMCharacterEmotionCurious: {
            matchingExpressions = @[
                                    @(RMCharacterExpressionBewildered),
                                    @(RMCharacterExpressionCurious),
                                    @(RMCharacterExpressionDizzy),
                                    @(RMCharacterExpressionLookingAround),
                                    @(RMCharacterExpressionPonder),
                                    @(RMCharacterExpressionTalking),
                                    @(RMCharacterExpressionHappy),
                                    ];
            break;
        }
            
        case RMCharacterEmotionDelighted:
        case RMCharacterEmotionExcited: {
            matchingExpressions = @[
                                    @(RMCharacterExpressionChuckle),
                                    @(RMCharacterExpressionExcited),
                                    @(RMCharacterExpressionHappy),
                                    @(RMCharacterExpressionPonder),
                                    @(RMCharacterExpressionLaugh),
                                    @(RMCharacterExpressionLove),
                                    @(RMCharacterExpressionProud),
                                    @(RMCharacterExpressionYippee),
                                    @(RMCharacterExpressionWant),
                                    ];
            break;
        }
            
        case RMCharacterEmotionHappy: {
            matchingExpressions = @[
                                    @(RMCharacterExpressionChuckle),
                                    @(RMCharacterExpressionExcited),
                                    @(RMCharacterExpressionHappy),
                                    @(RMCharacterExpressionPonder),
                                    @(RMCharacterExpressionLaugh),
                                    @(RMCharacterExpressionLove),
                                    @(RMCharacterExpressionProud),
                                    @(RMCharacterExpressionCurious),
                                    @(RMCharacterExpressionHoldingBreath),
                                    @(RMCharacterExpressionLookingAround),
                                    @(RMCharacterExpressionPonder),
                                    @(RMCharacterExpressionTalking),
                                    @(RMCharacterExpressionBored),
                                    @(RMCharacterExpressionYippee),
                                    @(RMCharacterExpressionWant),
                                    ];
            break;
        }
            
        case RMCharacterEmotionSad: {
            matchingExpressions = @[
                                    @(RMCharacterExpressionSad),
                                    @(RMCharacterExpressionScared),
                                    @(RMCharacterExpressionStartled),
                                    @(RMCharacterExpressionLetDown),
                                    @(RMCharacterExpressionDizzy),
                                    @(RMCharacterExpressionAngry),
                                    ];
            break;
        }
            
        case RMCharacterEmotionScared: {
            matchingExpressions = @[
                                    @(RMCharacterExpressionScared),
                                    @(RMCharacterExpressionStartled),
                                    @(RMCharacterExpressionLookingAround),
                                    ];
            break;
        }
            
        case RMCharacterEmotionSleeping:
        case RMCharacterEmotionSleepy: {
            matchingExpressions = @[
                                    @(RMCharacterExpressionSleepy),
                                    @(RMCharacterExpressionYawn),
                                    @(RMCharacterExpressionExhausted),
                                    @(RMCharacterExpressionDizzy),
                                    @(RMCharacterExpressionBored),
                                    ];
            break;
        }
    }
    return [matchingExpressions containsObject:@(expression)];
}

- (id)valueForParameterType:(RMParameterType)parameterType fromAction:(RMAction *)action
{
    for (RMParameter *parameter in action.parameters) {
        if (parameter.type == parameterType) {
            return parameter.value;
        }
    }
    return nil;
}

@end
