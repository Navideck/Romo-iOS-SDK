//
//  UIImage+Retina.m
//  RMCharacter
//

#import <Romo/UIImage+Cache.h>
#import <Romo/UIDevice+Romo.h>


@implementation UIImage (Cache)

static NSMutableDictionary *_cache;
static int _currentCapacity;
static const int _maxCapacity = 3500000;

+ (void)emptyCache {
    _cache = nil;
    _currentCapacity = 0;
}

+ cacheableImageNamed:(NSString*)name {
    if (!name.length) {
        return nil;
    }

    if (!_cache) {
        _cache = [NSMutableDictionary dictionaryWithCapacity:20];
    }

    if ([_cache objectForKey:name]) {
        return [_cache objectForKey:name];
    }

    NSArray *comps = [name componentsSeparatedByString:@"."];
    NSString* extension;
    if (comps.count < 2) {
        extension = @"png";
    } else {
        extension = comps[1];
    }

    UIImage *image = [UIImage imageNamed:comps[0]];
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
