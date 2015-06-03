//
//  RMSongActionIcon.m
//  Romo
//

#import "RMSongActionIcon.h"
#import <QuartzCore/QuartzCore.h>
#import "UIView+Additions.h"

@interface RMSongActionIcon ()

@property (nonatomic, strong) UIImageView *musicNote1;
@property (nonatomic, strong) UIImageView *musicNote2;
@property (nonatomic, strong) UIImageView *musicNote3;

@end

@implementation RMSongActionIcon

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        _musicNote1 = [[UIImageView alloc] initWithImage:[UIImage smartImageNamed:@"iconMusicNote.png"]];
        self.musicNote1.center = CGPointMake(18, 38);
        [self.contentView addSubview:self.musicNote1];
        
        _musicNote2 = [[UIImageView alloc] initWithImage:[UIImage smartImageNamed:@"iconMusicNote.png"]];
        self.musicNote2.center = CGPointMake(45, 54);
        self.musicNote2.transform = CGAffineTransformRotate(CGAffineTransformMakeScale(0.85, 0.85), 0.2);
        [self.contentView addSubview:self.musicNote2];

        _musicNote3 = [[UIImageView alloc] initWithImage:[UIImage smartImageNamed:@"iconMusicNote.png"]];
        self.musicNote3.center = CGPointMake(70, 33);
        self.musicNote3.transform = CGAffineTransformRotate(CGAffineTransformMakeScale(0.65, 0.65), 0.42);
        [self.contentView addSubview:self.musicNote3];
    }
    return self;
}

@end
