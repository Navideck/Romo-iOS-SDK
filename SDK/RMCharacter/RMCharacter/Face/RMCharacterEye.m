//
//  RMCharacterEye.m
//  RMCharacter
//

#import "RMCharacterEye.h"
#import "RMCharacterImage.h"
#import "RMMath.h"

@interface RMCharacterEye () {
    BOOL _left;
    
    float _h;
        
    CGRect _eyeFrame;

    UIView *_mask;
    CGRect _maskFrame;

    CGPoint _pupilCenter;
    CGFloat _pupilRadius;
}

@end

@implementation RMCharacterEye

+ (RMCharacterEye *)leftEye
{
    RMCharacterEye *eye = [[RMCharacterEye alloc] init];
    eye.left = YES;
    return eye;
}

+ (RMCharacterEye *)rightEye
{
    RMCharacterEye *eye = [[RMCharacterEye alloc] init];
    eye.left = NO;
    return eye;
}

- (id)init
{
    self = [super init];
    if (self) {
        self.contentMode = UIViewContentModeBottom;
        self.clipsToBounds = YES;
        
        _h = ([UIScreen mainScreen].bounds.size.height - 480)/2;

        _mask = [[UIView alloc] initWithFrame:CGRectZero];
        _mask.clipsToBounds = YES;
        [self addSubview:_mask];
        
        self.pupil = [RMCharacterPupil pupil];
    }
    return self;
}

- (void)setLeft:(BOOL)left
{
    if (left != _left) {
        _left = left;
        self.emotion = _emotion;
    }
}

- (void)setEmotion:(RMCharacterEmotion)emotion
{
    _emotion = emotion;
    self.image = [RMCharacterImage imageNamed:[NSString stringWithFormat:@"Romo_Emotion_%@eye_%d.png",_left ? @"L" : @"R", emotion]];
    self.pupil.dilation = 1.0;
    [_mask addSubview:self.pupil];
    switch (emotion) {
        case RMCharacterEmotionBewildered:
            if (_left) {
                _eyeFrame = (CGRect){32.5, 156.5 + _h, self.image.size};
                _maskFrame = CGRectMake(6, 3, 100, 100);
                _pupilCenter = CGPointMake(57, 27.5);
            } else {
                _eyeFrame = (CGRect){158.5, 134.0 + _h, self.image.size};
                _maskFrame = CGRectMake(3, 0, 100, 100);
                _pupilCenter = CGPointMake(42, 26.5);
            }
            _pupilRadius = 6;
            break;

        case RMCharacterEmotionCurious:
            if (_left) {
                _eyeFrame = (CGRect){41.5, 174.5 + _h, self.image.size};
                _maskFrame = CGRectMake(6, 0, 100, 100);
                _pupilCenter = CGPointMake(78, 56);
            } else {
                _eyeFrame = (CGRect){170.5, 156.5 + _h, self.image.size};
                _maskFrame = CGRectMake(0, 7, 100, 100);
                _pupilCenter = CGPointMake(22, 58);
            }
            _pupilRadius = 8;
            break;
            
        case RMCharacterEmotionExcited:
            if (_left) {
                _eyeFrame = (CGRect){40.5, 171.5 + _h, self.image.size};
                _maskFrame = CGRectMake(6, 0, 100, 100);
                _pupilCenter = CGPointMake(58, 51);
            } else {
                _eyeFrame = (CGRect){171, 162.5 + _h, self.image.size};
                _maskFrame = CGRectMake(0, 7, 100, 100);
                _pupilCenter = CGPointMake(44, 53);
            }
            _pupilRadius = 19;
            break;

        case RMCharacterEmotionHappy:
            if (_left) {
                _eyeFrame = (CGRect){40.5, 153.0 + _h, self.image.size};
                _maskFrame = CGRectMake(6, 3, 100, 100);
                _pupilCenter = CGPointMake(58, 48);
            } else {
                _eyeFrame = (CGRect){171.0, 144.0 + _h, self.image.size};
                _maskFrame = CGRectMake(3, 12, 100, 100);
                _pupilCenter = CGPointMake(41, 48);
            }
            _pupilRadius = 26;
            break;

        case RMCharacterEmotionIndifferent:
            if (_left) {
                _eyeFrame = (CGRect){46.5, 150.5 + _h, self.image.size};
                _maskFrame = CGRectMake(6, 3, 100, 100);
                _pupilCenter = CGPointMake(56.5, 51);
            } else {
                _eyeFrame = (CGRect){172.0, 147.5 + _h, self.image.size};
                _maskFrame = CGRectMake(0, 0, 100, 104);
                _pupilCenter = CGPointMake(35.5, 54);
            }
            _pupilRadius = 26;
            break;

        case RMCharacterEmotionSad:
            if (_left) {
                _eyeFrame = (CGRect){40.5, 191.0 + _h, self.image.size};
                _maskFrame = CGRectMake(-288, -743, 800, 800);
                _pupilCenter = CGPointMake(366, 795);
            } else {
                _eyeFrame = (CGRect){171.0, 185.5 + _h, self.image.size};
                _maskFrame = CGRectMake(-407, -739, 800, 800);
                _pupilCenter = CGPointMake(437, 798);
            }
            _pupilRadius = 7;
            break;
            
        case RMCharacterEmotionScared:
            if (_left) {
                _eyeFrame = (CGRect){40.5, 124.0 + _h, self.image.size};
                _maskFrame = CGRectMake(6, 3, 100, 120);
                _pupilCenter = CGPointMake(71, 62);
            } else {
                _eyeFrame = (CGRect){171.5, 115.5 + _h, self.image.size};
                _maskFrame = CGRectMake(3, 12, 100, 120);
                _pupilCenter = CGPointMake(30, 61);
            }
            _pupilRadius = 22;
            self.pupil.dilation = 0.5;
            break;
            
        case RMCharacterEmotionSleepy:
            if (_left) {
                _eyeFrame = (CGRect){40.5, 164.0 + _h, self.image.size};
                _maskFrame = CGRectMake(-194, -4.0, 700, 700);
                _pupilCenter = CGPointMake(272, 20.5);
            } else {
                _eyeFrame = (CGRect){170.0, 164 + _h, self.image.size};
                _maskFrame = CGRectMake(-398, -4.0, 700, 700);
                _pupilCenter = CGPointMake(428, 20.5);
            }
            _pupilRadius = 14;
            break;
    
        case RMCharacterEmotionSleeping:
            [self.pupil removeFromSuperview];
            if (_left) {
                _eyeFrame = (CGRect){40.5, 228.0 + _h, self.image.size};
            } else {
                _eyeFrame = (CGRect){171.0, 228 + _h, self.image.size};
            }
            break;
            
        default:
            break;
    }
    self.frame = _eyeFrame;
    _mask.frame = _maskFrame;
    _mask.layer.cornerRadius = _maskFrame.size.width/2.0;
    [self lookAtDefault];
}

- (void)setClose:(float)close
{
    if (close != _close) {
        close = MAX(0.0, MIN(1.0, close));
        float height = _eyeFrame.size.height * close;
        if (close < 0.95) {
            if (_close >= 0.95) {
                self.image = [RMCharacterImage imageNamed:[NSString stringWithFormat:@"Romo_Emotion_%@eye_%d.png",_left ? @"L" : @"R", _emotion]];
                self.clipsToBounds = YES;
            }
            self.frame = (CGRect){_eyeFrame.origin.x, _eyeFrame.origin.y + height, _eyeFrame.size.width, _eyeFrame.size.height - height};
            _mask.frame = (CGRect){_maskFrame.origin.x, _maskFrame.origin.y - height, _maskFrame.size};
            [self addSubview:_mask];
        } else {
            self.image = [RMCharacterImage imageNamed:[NSString stringWithFormat:@"Romo_Emotion_%@eye_Closed.png",_left ? @"L" : @"R"]];
            self.clipsToBounds = NO;
            [_mask removeFromSuperview];
        }
        _close = close;
    }
}

- (void)lookAtPoint:(RMPoint3D)point
{
    point.x = CLAMP(-1.0, point.x, 1.0);
    point.y = CLAMP(-1.0, point.y, 1.0);
    point.z = CLAMP( 0.0, point.z, 1.0);
    
    CGFloat x = (point.x * 64) + 12 * (0.9 - point.z) * (_left ? 1 : -1);
    CGFloat y = (point.y * 44);
    
    CGFloat dist = sqrtf(x*x + y*y);
    if (dist > _pupilRadius) {
        CGFloat theta = -atan2f(y, x);
        x = cosf(theta) * _pupilRadius;
        y = - sinf(theta) * _pupilRadius;
    }
    x += _pupilCenter.x;
    y += _pupilCenter.y;
    self.pupil.center = CGPointMake(x,y);
}

- (void)lookAtDefault
{
    [self lookAtPoint:RMPoint3DMake(0.0, 0.0, 0.9)];
}

@end
