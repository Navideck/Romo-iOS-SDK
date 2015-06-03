//
//  RMCharacterEye.h
//  RMCharacter
//

#import <UIKit/UIKit.h>
#import "RMCharacter.h"
#import "RMCharacterPupil.h"

@interface RMCharacterEye : UIImageView

@property (nonatomic) RMCharacterEmotion emotion;
@property (nonatomic) float close;
@property (nonatomic, strong) RMCharacterPupil *pupil;
@property (nonatomic) BOOL left;

+ (RMCharacterEye *)leftEye;
+ (RMCharacterEye *)rightEye;

- (void)lookAtPoint:(RMPoint3D)point;
- (void)lookAtDefault;

@end
