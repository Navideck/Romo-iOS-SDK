//
//  RMSongTableView.m
//  Romo
//

#import "RMSongTableView.h"
#import <MediaPlayer/MediaPlayer.h>
#import "RMSongTableViewCell.h"
#import "UIFont+RMFont.h"

@interface RMSongTableView () <UITableViewDataSource, UITableViewDelegate>

@property (nonatomic,strong) MPMediaQuery* songs;

@property (nonatomic, strong) UILabel *emptyLibraryLabel;

@end

@implementation RMSongTableView

- (id)initWithFrame:(CGRect)frame style:(UITableViewStyle)style
{
    self = [super initWithFrame:frame style:style];
    if (self) {
        self.dataSource = self;
        self.delegate = self;
        self.delaysContentTouches = YES;
        self.separatorStyle = UITableViewCellSeparatorStyleNone;
        self.backgroundColor = [UIColor clearColor];
        
        [self registerClass:[RMSongTableViewCell class] forCellReuseIdentifier:@"SongCell"];
    }
    return self;
}

- (void)reloadData
{
    self.songs = [MPMediaQuery songsQuery];
    [super reloadData];

    if (!self.songs.items.count) {
        if (!self.emptyLibraryLabel) {
            self.emptyLibraryLabel = [[UILabel alloc] initWithFrame:self.bounds];
            self.emptyLibraryLabel.text = NSLocalizedString(@"Play-Action-Empty-Library-Message", @"No music found in your iTunes library");
            self.emptyLibraryLabel.numberOfLines = 0;
            self.emptyLibraryLabel.font = [UIFont mediumFont];
            self.emptyLibraryLabel.backgroundColor = [UIColor clearColor];
            self.emptyLibraryLabel.textAlignment = NSTextAlignmentCenter;
            self.emptyLibraryLabel.textColor = [UIColor whiteColor];
            self.emptyLibraryLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        }
        self.tableHeaderView = self.emptyLibraryLabel;
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return 64.0;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return self.songs.itemSections.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    MPMediaQuerySection *querySection = self.songs.itemSections[section];
    return querySection.range.length;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    MPMediaQuerySection *querySection = self.songs.itemSections[section];
    return querySection.title;
}

- (UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section
{
    UIView *view = [[UIView alloc] init];
    view.backgroundColor = [UIColor clearColor];

    return view;
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section
{
    return (section == [self numberOfSectionsInTableView:tableView] - 1) ? 60.0 : 0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellIdentifier = @"SongCell";
	RMSongTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier forIndexPath:indexPath];

    MPMediaQuerySection *querySection = self.songs.itemSections[indexPath.section];
	cell.song = self.songs.items[querySection.range.location + indexPath.row];

    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    MPMediaQuerySection *querySection = self.songs.itemSections[indexPath.section];
	MPMediaItem *song = self.songs.items[querySection.range.location + indexPath.row];
    [self.songDelegate tableView:self didSelectSong:song];

    [[self cellForRowAtIndexPath:indexPath] setSelected:NO animated:YES];
}

@end
