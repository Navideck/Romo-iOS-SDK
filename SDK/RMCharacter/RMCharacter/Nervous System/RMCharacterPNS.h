//
//  RMCharacterPNS.h
//  RMCharacter
//

#import <Foundation/Foundation.h>
#import "RMCharacter.h"

typedef enum {
    RMCharacterPNSSignalBlink,
    RMCharacterPNSSignalDoubleBlink,
    RMCharacterPNSSignalLook,
    RMCharacterPNSSignalBreathe,
} RMCharacterPNSSignalType;

@protocol RMCharacterPNSDelegate;

@interface RMCharacterPNS : NSObject

@property (nonatomic, weak) id<RMCharacterPNSDelegate> delegate;

- (void)reset;
- (void)stop;

@end

@protocol RMCharacterPNSDelegate <NSObject>

- (void)didRecievePNSSignalWithType:(RMCharacterPNSSignalType)PNSSignalType;

@end