//
//  RMCharacterFaceEmotion.h
//  RMCharacter
//

#import <UIKit/UIKit.h>
#import "RMCharacter.h"

@interface RMCharacterFaceEmotion : UIView

@property (nonatomic) RMCharacterEmotion emotion;
@property (nonatomic) CGFloat pupilDilation;

- (void)lookAtPoint:(RMPoint3D)point animated:(BOOL)animated;
- (void)lookAtDefaultAnimated:(BOOL)animated;
- (void)blink;
- (void)doubleBlink;
- (void)closeLeftEye;
- (void)closeRightEye;
- (void)closeEyes;
- (void)openLeftEye;
- (void)openRightEye;
- (void)openEyes;

@end
