//
//  RMSayActionIcon.h
//  Romo
//

#import "RMActionIcon.h"
#import <Romo/RMCharacter.h>

@interface RMFaceActionIcon : RMActionIcon

/** Setting this shows a static frame of the emotion */
@property (nonatomic) RMCharacterEmotion emotion;

/** Setting this shows a static frame of the expression */
@property (nonatomic) RMCharacterExpression expression;

@end
