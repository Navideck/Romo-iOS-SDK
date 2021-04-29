//
//  UIImage+Cache.h
//  RMCharacter
//

#import <UIKit/UIKit.h>

@interface UIImage (Cache)

+ (void)emptyCache;

+ (UIImage* )cacheableImageNamed:(NSString*)name;

@end
