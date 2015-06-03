//
//  RMSongTableView.h
//  Romo
//

#import <UIKit/UIKit.h>

@class MPMediaItem;

@protocol RMSongTableViewDelegate;

@interface RMSongTableView : UITableView

@property (nonatomic, weak) id<RMSongTableViewDelegate> songDelegate;

@end

@protocol RMSongTableViewDelegate <NSObject>

- (void)tableView:(RMSongTableView *)tableView didSelectSong:(MPMediaItem *)song;

@end