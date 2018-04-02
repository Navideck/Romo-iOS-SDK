//
//  RAVVideoOutput.h
//  RomoAV
//

#import <Foundation/Foundation.h>
#import <CoreMedia/CoreMedia.h>

@interface VideoPacket : NSObject

@property uint8_t* buffer;
@property NSInteger size;

@end

@interface RAVVideoOutput : NSObject

- (UIView *)prepareOutputViewWithFrame:(CGRect)frame;
- (void)playVideoFrame:(void *)frame length:(uint32_t)length;

/// The remote streaming view.
@property (nonatomic) UIView *peerView;

- (void)stop;

@end
