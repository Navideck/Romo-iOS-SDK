//
//  UIImage+Retina.h
//  Romo
//

#import <UIKit/UIKit.h>

@interface UIImage (Retina)

/** Returns "name@1x.png" non-Retina version, always */
+ (UIImage *)nonRetinaImageNamed:(NSString *)name;

/** 
 If the device can't support Retina (either non-Retina display or weak device, according to [UIDevice+Hardware usesRetinaGraphics]),
 tries to fetch the nonRetinaImageNamed: version
 Falls back to @2x version if no @1x is found.
 */
+ (UIImage *)smartImageNamed:(NSString *)name;

@end
