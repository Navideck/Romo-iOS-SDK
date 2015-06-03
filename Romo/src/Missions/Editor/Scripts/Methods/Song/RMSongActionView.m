//
//  RMSongActionView.m
//  Romo
//

#import "RMSongActionView.h"
#import <QuartzCore/QuartzCore.h>
#import <MediaPlayer/MediaPlayer.h>
#import "UIView+Additions.h"
#import "UIFont+RMFont.h"
#import "RMSongTableView.h"

@interface RMSongActionView () <RMSongTableViewDelegate>

@property (nonatomic, strong) UIImageView *artwork;
@property (nonatomic, strong) UIImageView *artworkBorder;

@property (nonatomic, strong) MPMediaItem *song;

/** Expanded view list of songs */
@property (nonatomic, strong) RMSongTableView *songTableView;

@end

@implementation RMSongActionView

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [self.contentView addSubview:self.artwork];
        [self.contentView addSubview:self.artworkBorder];
    }
    return self;
}

- (void)setTitle:(NSString *)title
{
    super.title = title;
    self.song = _song;
}

- (void)setParameters:(NSArray *)parameters
{
    super.parameters = parameters;

    for (RMParameter *parameter in parameters) {
        if (parameter.type == RMParameterSong) {
            id songId = parameter.value;
            if (songId) {
                for (MPMediaItem *item in [MPMediaQuery songsQuery].items) {
                    if ([[item valueForProperty:MPMediaItemPropertyPersistentID] isEqual:songId]) {
                        self.song = item;
                    }
                }
            }
        }
    }
}

- (void)willLayoutForEditing:(BOOL)editing
{
    [super willLayoutForEditing:editing];
    
    if (editing) {
        self.songTableView.frame = CGRectMake(0, self.contentView.bottom + 80, self.contentView.width, self.contentView.height);
        self.songTableView.alpha = 0.0;
        [self.contentView addSubview:self.songTableView];
    } else {
        [self.contentView addSubview:self.artworkBorder];
    }
}

- (void)setEditing:(BOOL)editing
{
    super.editing = editing;
    
    if (editing) {
        CGFloat albumArtworkScale = (self.contentView.size.width * 0.65) / self.artworkBorder.width;
        self.artworkBorder.transform = CGAffineTransformMakeScale(albumArtworkScale, albumArtworkScale);
        self.artworkBorder.center = CGPointMake(self.contentView.centerX, self.artworkBorder.height / 2 + 50);

        CGFloat w = self.contentView.size.width * 0.65;
        self.artwork.frame = CGRectMake(self.artworkBorder.centerX - w/2, self.artworkBorder.centerY - w/2, w, w);
        
        self.artworkBorder.alpha = 0.0;
        
        self.songTableView.alpha = 1.0;
        self.songTableView.frame = CGRectMake(0, self.artworkBorder.bottom + 20,
                                              self.contentView.width, self.contentView.height - self.artworkBorder.bottom - 20);
    } else {
        self.artworkBorder.transform = CGAffineTransformIdentity;

        self.artwork.frame = CGRectMake((self.contentView.width - 75)/2, (self.contentView.height - 75)/2 + 14, 75, 75);
        self.artworkBorder.center = self.artwork.center;
        
        self.artworkBorder.alpha = 1.0;
        
        self.songTableView.alpha = 0.0;
        self.songTableView.frame = CGRectMake(0, self.contentView.bottom + 80,
                                              self.contentView.width, self.contentView.height);
    }
}

- (void)didLayoutForEditing:(BOOL)editing
{
    [super didLayoutForEditing:editing];
    
    if (editing) {
        [self.artworkBorder removeFromSuperview];
    } else {
        [self.songTableView removeFromSuperview];
    }
}

#pragma mark - Song Table View Delegate

- (void)tableView:(RMSongTableView *)tableView didSelectSong:(MPMediaItem *)song
{
    self.song = song;
}

#pragma mark - Private Methods

- (UIImageView *)artwork
{
    if (!_artwork) {
        _artwork = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, 75, 75)];
        _artwork.center = CGPointMake(self.contentView.width / 2, self.contentView.height / 2 + 14);
        _artwork.contentMode = UIViewContentModeScaleAspectFit;
        _artwork.layer.cornerRadius = 16.0;
        _artwork.clipsToBounds = YES;
    }
    return _artwork;
}

- (UIImageView *)artworkBorder
{
    if (!_artworkBorder) {
        _artworkBorder = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"artworkFrame.png"]];
        _artworkBorder.center = self.artwork.center;
    }
    return _artworkBorder;
}

- (RMSongTableView *)songTableView
{
    if (!_songTableView) {
        _songTableView = [[RMSongTableView alloc] initWithFrame:CGRectMake(0, 0, self.width, 0) style:UITableViewStylePlain];
        _songTableView.songDelegate = self;
    }
    return _songTableView;
}

- (void)setSong:(MPMediaItem *)song
{
    _song = song;
    UIImage *artworkImage = [[song valueForProperty:MPMediaItemPropertyArtwork] imageWithSize:CGSizeMake(self.artwork.width, self.artwork.height)];
    self.artwork.image = artworkImage ? artworkImage : [UIImage imageNamed:@"noArtwork.png"];

    NSString *songTitle = [song valueForProperty:MPMediaItemPropertyTitle];
    if (songTitle.length) {
        super.title = [NSString stringWithFormat:NSLocalizedString(@"Play-Action-Specific-Song-Title", @"Play “%@”"),songTitle];
    } else {
        super.title = NSLocalizedString(@"Play-Action-Generic-Song-Title", @"Play a song");
    }

    for (RMParameter *parameter in self.parameters) {
        if (parameter.type == RMParameterSong) {
            parameter.value = [song valueForProperty:MPMediaItemPropertyPersistentID];
        }
    }
}

@end
