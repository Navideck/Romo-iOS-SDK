//
//  RMCharacterFace.h
//  RMCharacter
//

#import <UIKit/UIKit.h>
#import "RMCharacter.h"
#import "RMCharacterImage.h"

@protocol RMCharacterFaceDelegate;

@interface RMCharacterFace : UIViewController

@property (nonatomic, weak)     id<RMCharacterFaceDelegate> delegate;
@property (nonatomic, readonly) RMCharacterType characterType;
@property (nonatomic)           RMCharacterEmotion emotion;
@property (nonatomic)           RMCharacterExpression expression;
@property (nonatomic)           CGFloat pupilDilation;
@property (nonatomic)           CGFloat rotation;

+ (RMCharacterFace *)faceWithCharacterType:(RMCharacterType)characterType;

- (void)setExpression:(RMCharacterExpression)expression withEmotion:(RMCharacterEmotion)emotion;
- (void)lookAtPoint:(RMPoint3D)point animated:(BOOL)animated;
- (void)lookAtDefault;
- (void)blink;
- (void)doubleBlink;
- (void)setLeftEyeOpen:(BOOL)leftEyeOpen rightEyeOpen:(BOOL)rightEyeOpen;
- (void)setFillColor:(UIColor *)fillColor percentage:(float)percentage;

@end

@protocol RMCharacterFaceDelegate <NSObject>

- (void)expressionFaceAnimationDidStart;
- (void)expressionFaceAnimationDidFinish;
- (void)expressionFaceAnimationDidHitBreakpoint;
- (void)didReceiveMemoryWarning;

@end
