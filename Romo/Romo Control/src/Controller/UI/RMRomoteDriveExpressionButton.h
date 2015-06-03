//
//  RMRomoteDriveExpressionButton.h
//

#import "RMRomoteDriveButton.h"
#ifndef ROMO_CONTROL_APP
#import <RMCharacter/RMCharacter.h>
#else
#define RMCharacterExpression uint
#endif

@interface RMRomoteDriveExpressionButton : RMRomoteDriveButton

@property (nonatomic) RMCharacterExpression expression;

+ (id)buttonWithExpression:(RMCharacterExpression)expression;

@end
