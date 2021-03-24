//
//  UIImage+Cache.h
//  Romo
//

#import <UIKit/UIKit.h>

@interface UIImage (Cache)

/** Returns "name@1x.png" non-Retina version, always */
//+ (UIImage *)nonRetinaImageNamed:(NSString *)name;

/** 
 If the device can't support Retina (either non-Retina display or weak device, according to [UIDevice+Romo usesRetinaGraphics]),
 tries to fetch the nonRetinaImageNamed: version
 Falls back to @2x version if no @1x is found.
 */
//+ (UIImage *)smartImageNamed:(NSString *)name;

+ (void)emptyCache;

+ (UIImage* )imageCacheNamed:(NSString*)name;

@end
