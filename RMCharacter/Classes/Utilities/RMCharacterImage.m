//
//  RMCharacterImage.m
//  RMCharacter
//

#import "RMCharacterImage.h"

#include <sys/socket.h> // Per msqr
#include <sys/sysctl.h>
#include <net/if.h>
#include <net/if_dl.h>
#import <Romo/UIDevice+Romo.h>

@implementation RMCharacterImage

static NSMutableDictionary *_cache;
static int _currentCapacity;
static const int _maxCapacity = 3500000;

+ (void)emptyCache {
    _cache = nil;
    _currentCapacity = 0;
}

+ (RMCharacterImage *)imageNamed:(NSString*)name {
    if (!name.length) {
        return nil;
    }
    
    if (!_cache) {
        _cache = [NSMutableDictionary dictionaryWithCapacity:20];
    }
    
    if ([_cache objectForKey:name]) {
        return (RMCharacterImage *)[_cache objectForKey:name];
    }
    
    NSArray *comps = [name componentsSeparatedByString:@"."];
    NSString* extension;
    if (comps.count < 2) {
        extension = @"png";
    } else {
        extension = comps[1];
    }

    NSBundle* bundle = [NSBundle bundleForClass:self.classForCoder];
    NSString *frameworkBundlePath = [[[bundle resourceURL] URLByAppendingPathComponent:@"RMCharacter.bundle"] path];
    NSBundle* characterBundle = [NSBundle bundleWithPath:frameworkBundlePath];

    RMCharacterImage *image = (RMCharacterImage *)[UIImage imageNamed:comps[0] inBundle:characterBundle compatibleWithTraitCollection:nil];
    if (image) {
        _currentCapacity += image.size.width * image.size.height;
        if (_currentCapacity > _maxCapacity) {
            [self emptyCache];
        }
        
        [_cache setObject:image forKey:[name lastPathComponent]];
    }
    
    return image;
}

@end
