//
//  RAVVideoOutput.h
//  RomoAV
//

#import <Foundation/Foundation.h>
#import <CoreMedia/CoreMedia.h>

@interface RAVVideoOutput : NSObject

- (UIView *)prepareOutputViewWithFrame:(CGRect)frame;
- (void)playVideoFrame:(void *)frame length:(NSUInteger)length;

/// The remote streaming view.
@property (nonatomic) UIView *peerView;

- (void)stop;

@end
