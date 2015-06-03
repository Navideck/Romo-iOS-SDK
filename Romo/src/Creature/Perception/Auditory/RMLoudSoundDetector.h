//
//  RMLoudSoundDetector.h
//  Romo
//

#import <Foundation/Foundation.h>

@protocol RMLoudSoundDetectorDelegate;

@interface RMLoudSoundDetector : NSObject

@property (nonatomic, weak) id<RMLoudSoundDetectorDelegate> delegate;

@end

@protocol RMLoudSoundDetectorDelegate <NSObject>

- (void)loudSoundDetectorDetectedLoudSound:(RMLoudSoundDetector *)loudSoundDetector;
- (void)loudSoundDetectorDetectedEndOfLoudSound:(RMLoudSoundDetector *)loudSoundDetector;

@end
