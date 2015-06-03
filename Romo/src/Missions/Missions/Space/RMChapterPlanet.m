//
//  RMChapterPlanet.m
//  Romo
//

#import "RMChapterPlanet.h"
#import "UIView+Additions.h"
#import "UIFont+RMFont.h"
#import "RMSpriteView.h"

static const float frameRate = 30;

/** Glow image assets are scaled down by this amount (e.g. 0.2 = 20%) */
static const CGFloat glowScale = 0.2;

@interface RMChapterPlanet ()

@property (nonatomic, strong) UIImageView *glow;
@property (nonatomic, strong) RMSpriteView *spacePlanet;

@property (nonatomic, readwrite) RMChapter chapter;
@property (nonatomic, readwrite) RMChapterStatus status;

@end

@implementation RMChapterPlanet

- (id)initWithChapter:(RMChapter)chapter status:(RMChapterStatus)status
{
    self = [super initWithFrame:(CGRect){0,0, [self desiredSizeForChapter:chapter]}];
    if (self) {
        _status = status;
        _chapter = chapter;

        _glow = [[UIImageView alloc] initWithImage:nil];
        self.glow.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        self.glow.contentMode = UIViewContentModeScaleAspectFill;
        [self addSubview:self.glow];

        if (status == RMChapterStatusLocked) {
            self.glow.alpha = 0.5;
            self.glow.image = [UIImage imageNamed:[NSString stringWithFormat:@"planet%dGlow.png",chapter]];

            if (!self.glow.image) {
                self.glow.image = [UIImage imageNamed:@"planetLockedGlow.png"];
            }
            
            UIImageView *planet = [[UIImageView alloc] initWithImage:[UIImage imageNamed:[NSString stringWithFormat:@"planet%dLocked.png", chapter]]];
            if (!planet.image) {
                planet.image = [UIImage imageNamed:@"planetLocked.png"];
            }
            planet.frame = self.bounds;
            planet.contentMode = UIViewContentModeScaleAspectFit;
            [self addSubview:planet];
        } else {
            self.glow.image = [UIImage imageNamed:[NSString stringWithFormat:@"planet%dGlow.png",chapter]];

            _spacePlanet = [[RMSpriteView alloc] initWithFrame:(CGRect){0, 0, [self sizeForChapter:chapter]}
                                                    spriteName:[NSString stringWithFormat:@"planet%dSprite", chapter]
                                                   repeatCount:HUGE_VALF
                                                  autoreverses:(chapter == RMChapterTheLab)
                                               framesPerSecond:frameRate];
            self.spacePlanet.transform = CGAffineTransformMakeScale(self.width / self.spacePlanet.width, self.height / self.spacePlanet.height);
            self.spacePlanet.center = CGPointMake(self.width / 2.0, self.height / 2.0);
            [self addSubview:self.spacePlanet];
        }
        
        self.glow.size = CGSizeMake(self.glow.image.size.width / glowScale, self.glow.image.size.height / glowScale);
        self.glow.center = CGPointMake(self.width / 2.0, self.height / 2.0);
    }
    return self;
}

- (CGSize)sizeForChapter:(RMChapter)chapter
{
    switch (chapter) {
        case RMChapterOne: return CGSizeMake(135.0, 135.0); break;
        case RMChapterTwo: return CGSizeMake(106.0, 106.0); break;
        case RMChapterTheLab: return CGSizeMake(198.0, 99.0); break;
        case RMChapterThree: return CGSizeMake(112, 112.0); break;
        case RMChapterRomoControl: return CGSizeMake(143.0, 143.0); break;
        default: return CGSizeMake(120, 120); break;
    }
}

- (CGSize)desiredSizeForChapter:(RMChapter)chapter
{
    switch (chapter) {
        case RMChapterOne: return CGSizeMake(146, 146); break;
        case RMChapterTwo: return CGSizeMake(110, 110); break;
        case RMChapterTheLab: return CGSizeMake(264, 132); break;
        case RMChapterThree: return CGSizeMake(144, 144.0); break;
        case RMChapterRomoControl: return CGSizeMake(153.0, 153.0); break;
        default: return CGSizeMake(120, 120); break;
    }
}

@end
