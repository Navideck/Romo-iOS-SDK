//
//  UIDevice+Romo.h
//  CocoaLumberjack
//
//  Created by Foti Dim on 11.02.19.
//

#import <UIKit/UIKit.h>
#import <UIDevice-Hardware/UIDevice-Hardware.h>

NS_ASSUME_NONNULL_BEGIN

@interface UIDevice (Romo)

/**
 Determines if this device is "fast"
 Used for running algorithms at higher frequencies, using Retina graphics, etc.
 Returns true for iPad 4+, iPhone 4S+, iPod 5+
 */
- (BOOL)isFastDevice;
- (BOOL)isDockableTelepresenceDevice;
- (BOOL)isTelepresenceController;
- (BOOL)hasLightningConnector;
- (BOOL)isIphoneThreeOrOlder;
- (BOOL)hasRetinaDisplay;

@end

NS_ASSUME_NONNULL_END
