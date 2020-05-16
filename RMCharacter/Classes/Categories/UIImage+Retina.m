//
//  UIImage+Retina.m
//  Romo
//

#import "UIImage+Retina.h"
#import <Romo/UIDevice+Romo.h>


@implementation UIImage (Retina)

+ (UIImage *)nonRetinaImageNamed:(NSString *)name
{
    NSString *resource = name;
    NSString *type = [name pathExtension];
    if (type.length) {
        resource = [name substringToIndex:name.length - 1 - type.length];
        name = [resource stringByAppendingPathExtension:type];
    } else {
        name = resource;
    }

    NSBundle* bundle = [NSBundle bundleForClass:self.classForCoder];
    NSString *frameworkBundlePath = [[[bundle resourceURL] URLByAppendingPathComponent:@"RMCharacter.bundle"] path];
    NSBundle* characterBundle = [NSBundle bundleWithPath:frameworkBundlePath];
    UIImage *image = [self imageNamed:name inBundle:characterBundle compatibleWithTraitCollection:nil];
    return image;
}

+ (UIImage *)smartImageNamed:(NSString *)name
{
    BOOL retina = [[UIDevice currentDevice] usesRetinaGraphics];
    UIImage *result = nil;
        
    if (!retina) {
        result = [self nonRetinaImageNamed:name];
    }

    if (!result) {
        result = [self imageNamed:name];
    }

    return result;
}

@end
