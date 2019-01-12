//
//  RMSpriteView.m
//  TestSprite
//

#import "RMSpriteView.h"
#import "UIView+Additions.h"
#import "UIImage+Retina.h"

static NSString *animationKey = @"spriteAnimation";

@interface RMSpriteView ()

@property (nonatomic, strong, readwrite) NSString *spriteName;
@property (nonatomic, assign, readwrite) NSUInteger repeatCount;
@property (nonatomic, assign, readwrite) BOOL autoreverses;
@property (nonatomic, assign, readwrite) CGFloat framesPerSecond;

// Private Properties
@property (nonatomic, strong) NSArray *sprites;
@property (nonatomic, strong) UIView *spritesView;
@property (nonatomic, strong) NSDictionary *spriteMetaData;
@property (nonatomic, strong) CAAnimationGroup *spriteAnimationGroup;

/** Flag for whether we should restart animation on foreground */
@property (nonatomic, getter=isAnimating) BOOL animating;

@end

@implementation RMSpriteView

- (instancetype)initWithFrame:(CGRect)frame
                   spriteName:(NSString *)spriteName
                  repeatCount:(NSUInteger)repeatCount
                 autoreverses:(BOOL)autoreverses
              framesPerSecond:(CGFloat)framesPerSecond
{
    self = [super initWithFrame:frame];
    if (self) {
        _spriteName = spriteName;
        _repeatCount = repeatCount;
        _autoreverses = autoreverses;
        _framesPerSecond = framesPerSecond;
        
        [self addSubview:self.spritesView];
        
        // CAAnimations are auto-removed on background, so we'll re-enable them on foreground
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleApplicationWillEnterForegroundNotification:)
                                                     name:UIApplicationWillEnterForegroundNotification
                                                   object:nil];
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - View location changes

- (void)didMoveToSuperview
{
    if (self.window) {
        [self startAnimating];
    } else {
        [self stopAnimating];
    }
}

- (void)didMoveToWindow
{
    [self didMoveToSuperview];
}

#pragma mark - Image and image view

- (NSArray *)sprites
{
    if (!_sprites) {
        NSMutableArray *sprites = [NSMutableArray arrayWithCapacity:3];
        
        int i = 1;
        while (1) {
            UIImage *sprite;
            if (i == 1) {
                sprite = [UIImage smartImageNamed:[self.spriteName stringByAppendingString:@".png"]];
            } else {
                sprite = [UIImage smartImageNamed:[NSString stringWithFormat:@"%@%d.png", self.spriteName, i]];
            }
            
            if (sprite) {
                [sprites addObject:sprite];
                i++;
            } else {
                break;
            }
        }
        
        _sprites = [NSArray arrayWithArray:sprites];
    }
    return _sprites;
}

- (UIView *)spritesView
{
    if (!_spritesView) {
        _spritesView = [[UIView alloc] initWithFrame:CGRectZero];
        _spritesView.clipsToBounds = YES;
        _spritesView.layer.anchorPoint = CGPointMake(0, 0);
        
        CGFloat yOffset = 0;
        for (int i = 0; i < self.sprites.count; i++) {
            UIImageView *nextSpriteView = [[UIImageView alloc] initWithImage:self.sprites[i]];
            nextSpriteView.top = yOffset;
            [_spritesView addSubview:nextSpriteView];
            yOffset += nextSpriteView.image.size.height;
        }
    }
    return _spritesView;
}

#pragma mark - Loading meta data

- (NSDictionary *)spriteMetaData
{
    if (!_spriteMetaData) {
        NSData *data = [NSData dataWithContentsOfFile:[[NSBundle mainBundle] pathForResource:self.spriteName ofType:@"json"]];
        if (data) {
            _spriteMetaData = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        }
    }
    return _spriteMetaData;
}

#pragma mark - Sprite animation

- (void)startAnimating
{
    self.animating = YES;
    [self.spritesView.layer addAnimation:self.spriteAnimationGroup forKey:animationKey];
}

- (void)stopAnimating
{
    self.animating = NO;
    [self.spritesView.layer removeAnimationForKey:animationKey];
}

- (CAAnimationGroup *)spriteAnimationGroup
{
    if (!_spriteAnimationGroup) {
        __block NSInteger frameCount = [self.spriteMetaData[@"1"] count] * self.spriteMetaData.count;
        
        // For each peice of meta data, we create an animation frame for the bounds, position and contentsRect
        // changes. These will be used by the CAKeyframeAnimations.
        NSMutableArray *boundsFrames = [NSMutableArray arrayWithCapacity:frameCount];
        NSMutableArray *contentsRectFrames = [NSMutableArray arrayWithCapacity:frameCount];
        NSMutableArray *positionFrames = [NSMutableArray arrayWithCapacity:frameCount];
        
        __block CGFloat yOffset = 0;
        frameCount = 0;
        [self.spriteMetaData enumerateKeysAndObjectsUsingBlock:^(NSNumber *sheetIndex, NSArray *spriteMetaData, BOOL *stop) {
            frameCount += spriteMetaData.count;
            int index = sheetIndex.intValue - 1;
            UIImage *spriteSheet = self.sprites[index];
            
            [spriteMetaData enumerateObjectsUsingBlock:^(NSDictionary *frameData, NSUInteger idx, BOOL *stop) {
                NSDictionary *boundsDict = frameData[@"f"];
                CGRect bounds = CGRectMake([boundsDict[@"x"] floatValue] / 2.0,
                                           [boundsDict[@"y"] floatValue] / 2.0 + yOffset,
                                           [boundsDict[@"w"] floatValue] / 2.0,
                                           [boundsDict[@"h"] floatValue] / 2.0);
                [boundsFrames addObject:[NSValue valueWithCGRect:bounds]];
                
                CGRect contentRect = CGRectMake(([boundsDict[@"x"] floatValue] / 2.0) / spriteSheet.size.width,
                                                ([boundsDict[@"y"] floatValue] / 2.0) / spriteSheet.size.height + yOffset,
                                                ([boundsDict[@"w"] floatValue] / 2.0) / spriteSheet.size.width,
                                                ([boundsDict[@"h"] floatValue] / 2.0) / spriteSheet.size.height);
                [contentsRectFrames addObject:[NSValue valueWithCGRect:contentRect]];
                
                CGPoint position = CGPointMake([frameData[@"s"][@"x"] floatValue] / 2.0,
                                               [frameData[@"s"][@"y"] floatValue] / 2.0);
                [positionFrames addObject:[NSValue valueWithCGPoint:position]];
            }];
            
            yOffset += spriteSheet.size.height;
        }];
        
        // The bounds animation sizes the frame of the sprite to be exactly the size of the sprite frame's size
        CAKeyframeAnimation *boundsAnimation = [CAKeyframeAnimation animationWithKeyPath:@"bounds"];
        boundsAnimation.values = [boundsFrames copy];
        boundsAnimation.calculationMode = kCAAnimationDiscrete;
        
        // The contentsRect animation positions the actual sprite image at the current frame's location
        CAKeyframeAnimation *contentsRectAnimation = [CAKeyframeAnimation animationWithKeyPath:@"contentsRect"];
        contentsRectAnimation.values = [contentsRectFrames copy];
        contentsRectAnimation.calculationMode = kCAAnimationDiscrete;
        
        // Because each frame of the sprite's animation can be different size, the position animation offsets
        // the sprites layer to keep each frame aligned
        CAKeyframeAnimation *positionAnimation = [CAKeyframeAnimation animationWithKeyPath:@"position"];
        positionAnimation.values = [positionFrames copy];
        positionAnimation.calculationMode = kCAAnimationDiscrete;
        
        // Finally the animation group makes sure the previously defined animations run in sync
        CAAnimationGroup *animationGroup = [[CAAnimationGroup alloc] init];
        animationGroup.animations = @[boundsAnimation, contentsRectAnimation, positionAnimation];
        animationGroup.duration = frameCount / self.framesPerSecond;
        animationGroup.repeatCount = self.repeatCount;
        animationGroup.autoreverses = self.autoreverses;
        _spriteAnimationGroup = animationGroup;
    }
    return _spriteAnimationGroup;
}

#pragma mark - Notifications

- (void)handleApplicationWillEnterForegroundNotification:(NSNotification *)notification
{
    if (self.isAnimating) {
        [self startAnimating];
    }
}

#ifdef DEBUG
/**
 Recalculates x & y offsets of a sprite to center it on (0,0) then NSLogs the JSON
 NOTE: currently only works for 1-sheeted sprites currently
 */
- (void)repositionSpriteToCenter:(NSString *)spriteName
{
    // manual offsets:
    CGFloat xOffset = 48;
    CGFloat yOffset = 24;
    
    NSData *data = [NSData dataWithContentsOfFile:[[NSBundle mainBundle] pathForResource:self.spriteName ofType:@"json"]];
    NSDictionary *spriteMetaData = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    NSArray *sprites = spriteMetaData[@"1"];
    
    CGFloat averageX = 0;
    CGFloat averageY = 0;
    for (NSDictionary *frameData in sprites) {
        CGFloat x = [frameData[@"s"][@"x"] floatValue];
        CGFloat y = [frameData[@"s"][@"y"] floatValue];
        averageX += x;
        averageY += y;
    }
    averageX /= sprites.count;
    averageY /= sprites.count;
    NSLog(@"New average x = %f, average y = %f", averageX, averageY);
    
    NSMutableArray *newSprites = [NSMutableArray arrayWithCapacity:sprites.count];
    for (NSDictionary *frameData in sprites) {
        float oldX = [frameData[@"s"][@"x"] floatValue];
        float oldY = [frameData[@"s"][@"y"] floatValue];
        NSDictionary *newFrameData = @{ @"f" : frameData[@"f"],
                                        @"s" : @{ @"x" : @(oldX - averageX + xOffset), @"y" : @(oldY - averageY + yOffset) }
                                        };
        [newSprites addObject:newFrameData];
    }
    NSDictionary *newMetaData = @{ @"1" : newSprites };
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:newMetaData options:0 error:0];
    NSLog(@"\nREPOSITIONED JSON DATA:\n%@\n\n", [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding]);
}
#endif

@end
