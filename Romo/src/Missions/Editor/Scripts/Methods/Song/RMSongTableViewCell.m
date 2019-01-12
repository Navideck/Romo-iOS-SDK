//
//  RMSongTableViewCell.m
//  Romo
//

#import "RMSongTableViewCell.h"
#import <MediaPlayer/MediaPlayer.h>
#import <QuartzCore/QuartzCore.h>
#import "UIView+Additions.h"
#import "UIFont+RMFont.h"

@interface RMSongTableViewCell ()

@property (nonatomic, strong) UIImageView *albumArtwork;

@property (nonatomic, strong) UILabel *songTitleLabel;
@property (nonatomic, strong) UILabel *artistTitleLabel;

@end

@implementation RMSongTableViewCell

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.contentView.backgroundColor = [UIColor clearColor];
        
        _albumArtwork = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, 64, 64)];
        self.albumArtwork.backgroundColor = [UIColor blueColor];
        self.albumArtwork.layer.borderWidth = 1.0;
        self.albumArtwork.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.2].CGColor;
        [self addSubview:self.albumArtwork];

        _songTitleLabel = [[UILabel alloc] initWithFrame:CGRectMake(78, 12, self.width - 88, 22)];
        self.songTitleLabel.backgroundColor = self.contentView.backgroundColor;
        self.songTitleLabel.font = [UIFont mediumFont];
        self.songTitleLabel.textColor = [UIColor whiteColor];
        [self addSubview:self.songTitleLabel];

        _artistTitleLabel = [[UILabel alloc] initWithFrame:CGRectMake(78, 36, self.width - 88, 18)];
        self.artistTitleLabel.backgroundColor = self.contentView.backgroundColor;
        self.artistTitleLabel.font = [UIFont smallFont];
        self.artistTitleLabel.textColor = [UIColor colorWithRed:0.176 green:0.672 blue:0.999 alpha:1.000];
        [self addSubview:self.artistTitleLabel];
}
    return self;
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated
{
    [super setSelected:selected animated:animated];

    // Configure the view for the selected state
}

- (void)setSong:(MPMediaItem *)song
{
    _song = song;

    if (song) {
        NSString *songTitle = [song valueForProperty:MPMediaItemPropertyTitle];
        self.songTitleLabel.text = songTitle.length ? songTitle : NSLocalizedString(@"(Unknown Title)",@"(Unknown Title)");

        NSString *artistTitle = [song valueForProperty:MPMediaItemPropertyArtist];
        self.artistTitleLabel.text = artistTitle.length ? artistTitle : NSLocalizedString(@"(Unknown Artist)",@"(Unknown Artist)");

        UIImage *albumArtworkImage = [[song valueForProperty:MPMediaItemPropertyArtwork] imageWithSize:CGSizeMake(self.height, self.height)];
        self.albumArtwork.image = albumArtworkImage ? albumArtworkImage : [UIImage imageNamed:@"noArtwork.png"];
;
    }
}

@end
