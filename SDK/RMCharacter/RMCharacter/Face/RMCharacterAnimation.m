//
//  RMCharacterAnimation.m
//

#import "RMCharacterAnimation.h"
#import "RMCharacter.h"
#import "RMMath.h"

typedef void (^BoolBlock)(BOOL);

@interface RMCharacterAnimation () {
    UIImageView* _sprite;
    NSArray* _crop;
    
    NSMutableArray* _sprites;
    NSMutableArray* _crops;
    
    int _frameCount;
    int _accumulatedFrames;
    NSTimer* _timer;
    
    CFAbsoluteTime _startTime;
    CFAbsoluteTime _endTime;
    
    CGFloat _h;
    
    BOOL _reversed;
    
    NSString* _prefix;
    int _index;
}

@property (nonatomic, strong) RMCharacterImage* staticImage;
@property (nonatomic, copy)   BoolBlock completion;

- (RMCharacterImage *)spriteSheet:(int)index withPrefix:(NSString *)prefix;
- (NSString *)prefixWithAction:(RMAnimatedAction)action forExpression:(RMCharacterExpression)expression;

@end

@implementation RMCharacterAnimation

- (void)startAnimating
{
    [_timer invalidate];
    
    self.staticImage = (RMCharacterImage *)self.image;
    
    _index = 1;
    _sprite.image = [self spriteSheet:_index withPrefix:_prefix];
    [self addSubview:_sprite];
    
    _startTime = currentTime();
    _endTime = _startTime + (1.0/24.0)*_frameCount;
    
    _animating = YES;
    [self.delegate animationDidStart];
    super.image = nil;
    
    [self _nextFrame];
    _timer = [NSTimer timerWithTimeInterval:1.0/24.0 target:self selector:@selector(_nextFrame) userInfo:nil repeats:YES];
    [[NSRunLoop currentRunLoop] addTimer:_timer forMode:NSRunLoopCommonModes];
}

- (void)dealloc
{
    [_timer invalidate];
}

- (void)stopAnimating
{
    [_timer invalidate];
    _timer = nil;
    _animating = NO;
    
    self.frame = (CGRect){CGPointZero, self.frame.size};
    self.contentMode = UIViewContentModeCenter;
    self.image = self.staticImage;
    
    [_sprite removeFromSuperview];
    _sprite.image = nil;
    _crop = nil;
    
    _sprites = nil;
    _crops = nil;
    
    _reversed = NO;
    
    if (self.completion) {
        self.completion(YES);
    }
}

- (void)_nextFrame
{
    double curTime = currentTime();
    int currentFrame = (int)(24.0*(curTime - _startTime)) - _accumulatedFrames;
    if (curTime > _endTime || currentFrame >= _frameCount + _accumulatedFrames) {
        [self stopAnimating];
    } else if (currentFrame >= _crop.count) {
        _index++;
        _accumulatedFrames += _crop.count;
        _breakpointFrame -= _crop.count;
        _sprite.image = [self spriteSheet:_index withPrefix:_prefix];
        if (_sprite.image) {
            [self _nextFrame];
        } else {
            [self stopAnimating];
        }
    } else {
        if (currentFrame >= self.breakpointFrame && self.breakpointFrame >= 0) {
            [self.delegate animationReachedBreakpointAtFrame:currentFrame];
            _breakpointFrame = -1;
        }
        
        int frameIndex = _reversed ? (_crop.count - currentFrame - 1) : currentFrame;
        NSDictionary* crop = _crop[frameIndex];
        NSDictionary* frame = crop[@"frame"];
        NSDictionary* sourceFrame = crop[@"spriteSourceSize"];
        CGFloat w = ((NSString *)frame[@"w"]).floatValue/2.0;
        CGFloat h = ((NSString *)frame[@"h"]).floatValue/2.0;
        CGFloat x = ((NSString *)frame[@"x"]).floatValue/2.0;
        CGFloat y = ((NSString *)frame[@"y"]).floatValue/2.0;
        CGFloat drawX = ((NSString *)sourceFrame[@"x"]).floatValue/2.0;
        CGFloat drawY = ((NSString *)sourceFrame[@"y"]).floatValue/2.0;
        BOOL rotated = ((NSString *)crop[@"rotated"]).boolValue;
        
        if (rotated) {
            _sprite.contentMode = UIViewContentModeTopRight;
            _sprite.transform = CGAffineTransformMakeRotation(-M_PI_2);
            _sprite.frame = CGRectMake(-y, -_sprite.image.size.width + x + h, y + w, _sprite.image.size.width - x);
        } else {
            _sprite.contentMode = UIViewContentModeTopLeft;
            _sprite.transform = CGAffineTransformIdentity;
            _sprite.frame = CGRectMake(-x, -y, x + w, y + h);
        }
        self.frame = (CGRect){CGPointMake(drawX, drawY + _h), self.frame.size};
    }
}

- (void)animateWithAction:(RMAnimatedAction)action forEmotion:(RMCharacterEmotion)emotion completion:(void (^)(BOOL))completion
{
    self.completion = completion;
    _reversed = NO;
    switch (action) {
        case RMAnimatedActionOutro:
            _reversed = YES;
        case RMAnimatedActionIntro:
            if (emotion != RMCharacterEmotionSleeping) {
                _prefix = [NSString stringWithFormat:@"Romo_Emotion_Transition_%d",emotion];
            } else {
                if (completion) {
                    completion(YES);
                }
                return;
            }
            break;
            
        case RMAnimatedActionIdleEmotion:
            break;
            
        case RMAnimatedActionBlink:
            
            _prefix = [NSString stringWithFormat:@"Romo_Emotion_Blink_%d",emotion];
            break;
            
        default:
            return;
    }
    [self startAnimating];
}

- (void)animateWithAction:(RMAnimatedAction)action forExpression:(RMCharacterExpression)expression completion:(void (^)(BOOL))completion
{
    self.completion = completion;
    _reversed = NO;
    switch (action) {
        case RMAnimatedActionOutro:
            _reversed = YES;
        case RMAnimatedActionIntro:
            _prefix = [self prefixWithAction:action forExpression:expression];
            if (!_prefix.length) {
                self.completion(YES);
                return;
            }
            break;
            
        case RMAnimatedActionExpression:
            _prefix = [NSString stringWithFormat:@"Romo_Expression_%d",expression];
            break;
            
        default:
            return;
    }
    [self startAnimating];
}

- (RMCharacterImage *)spriteSheet:(int)index withPrefix:(NSString *)prefix
{
    if (index == 1) {
        _sprites = [NSMutableArray arrayWithCapacity:3];
        _crops = [NSMutableArray arrayWithCapacity:3];
        _frameCount = 0;
        while (1) {
            RMCharacterImage* sprite = [RMCharacterImage smartImageNamed:[NSString stringWithFormat:@"%@_%d.png",prefix,index]];
            if (sprite) {
                NSString* cropFile = [NSString stringWithFormat:@"%@_%d",prefix,index];
                
                NSString* mainBundlePath = [[NSBundle mainBundle] resourcePath];
                NSString* frameworkBundlePath = [mainBundlePath stringByAppendingPathComponent:@"RMCharacter.bundle"];
                NSBundle* characterBundle = [NSBundle bundleWithPath:frameworkBundlePath];
                NSData* cropData = [NSData dataWithContentsOfFile:[characterBundle pathForResource:cropFile ofType:@"json"]];
                NSArray* crop = [NSJSONSerialization JSONObjectWithData:cropData options:0 error:nil][@"frames"];
                _frameCount += crop.count;
                [_crops addObject:crop];
                [_sprites addObject:sprite];
                index++;
            } else {
                break;
            }
        }
        _accumulatedFrames = 0;
        _crop = _crops[0];
        return _sprites[0];
    } else if (index > 0 && index <= _sprites.count) {
        _crop = _crops[index - 1];
        RMCharacterImage *sprite = _sprites[index - 1];
        
        [_crops replaceObjectAtIndex:index - 1 withObject:[NSNull null]];
        [_sprites replaceObjectAtIndex:index - 1 withObject:[NSNull null]];
        
        return sprite;
    }
    return nil;
}

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.clipsToBounds = YES;
        self.contentMode = UIViewContentModeCenter;
        
        _sprite = [[UIImageView alloc] init];
        _sprite.clipsToBounds = YES;
        
        _h = (self.frame.size.height - 480)/2;
    }
    return self;
}

/**
 Some expressions don't include a blink-through transition for either the intro, outro, or both
 And instead, they reuse the blink-through transition from an emotion
 e.g. Curious expression should use Curious emotion's blink-through for both intro & outro
 */
- (NSString *)prefixWithAction:(RMAnimatedAction)action forExpression:(RMCharacterExpression)expression
{
    if (action == RMAnimatedActionIntro || action == RMAnimatedActionOutro) {
        switch (expression) {
            case RMCharacterExpressionAngry:
                return nil;
                
            case RMCharacterExpressionBored:
                return nil;
                
            case RMCharacterExpressionChuckle:
                return nil;
                
            case RMCharacterExpressionCurious:
                return @"Romo_Emotion_Transition_1";
                
            case RMCharacterExpressionDizzy:
                return nil;
                
            case RMCharacterExpressionEmbarrassed:
                return nil;
                
            case RMCharacterExpressionExcited:
                if (action == RMAnimatedActionIntro) return nil;
                return @"Romo_Emotion_Transition_2";

            case RMCharacterExpressionExhausted:
                return nil;

            case RMCharacterExpressionFart:
                if (action == RMAnimatedActionOutro) return nil;
                return @"Romo_Emotion_Transition_3";

            case RMCharacterExpressionHappy:
            case RMCharacterExpressionProud:
                if (action == RMAnimatedActionIntro) return nil;
                return @"Romo_Emotion_Transition_3";

            case RMCharacterExpressionHiccup:
                return nil;

            case RMCharacterExpressionBewildered:
                return @"Romo_Emotion_Transition_9";

            case RMCharacterExpressionHoldingBreath:
                return nil;

            case RMCharacterExpressionLaugh:
                if (action == RMAnimatedActionIntro) return nil;
                return @"Romo_Emotion_Transition_2";
                
            case RMCharacterExpressionLookingAround:
                if (action == RMAnimatedActionIntro) return nil;
                return @"Romo_Emotion_Transition_1";
                
            case RMCharacterExpressionLove:
                return nil;
                
            case RMCharacterExpressionPonder:
                if (action == RMAnimatedActionIntro) return nil;
                return @"Romo_Emotion_Transition_1";
                
            case RMCharacterExpressionSad:
            case RMCharacterExpressionLetDown:
                return @"Romo_Emotion_Transition_4";
                
            case RMCharacterExpressionScared:
                return @"Romo_Emotion_Transition_5";
                
            case RMCharacterExpressionSleepy:
                return @"Romo_Emotion_Transition_6";
                
            case RMCharacterExpressionSneeze:
                return nil;
                
            case RMCharacterExpressionTalking:
                return nil;

            case RMCharacterExpressionWant:
                if (action == RMAnimatedActionIntro) return nil;
                return @"Romo_Emotion_Transition_10";

            case RMCharacterExpressionYawn:
                if (action == RMAnimatedActionIntro) return nil;
                return @"Romo_Emotion_Transition_6";

            case RMCharacterExpressionYippee:
                return nil;
                
            default:
                return nil;
        }
    }
    return nil;
}

- (void)setImage:(RMCharacterImage *)image
{
    if (_animating) {
        self.staticImage = image;
    } else {
        super.image = image;
    }
}

- (void)didReceiveMemoryWarning
{
    [RMCharacterImage emptyCache];
}

@end