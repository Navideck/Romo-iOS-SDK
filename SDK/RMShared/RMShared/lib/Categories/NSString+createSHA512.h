//
//  NSString+createSHA512.h
//  Romo
//
//
// Credit: http://stackoverflow.com/questions/3829068/hash-a-password-string-using-sha512-like-c-sharp

#import <Foundation/Foundation.h>

@interface NSString (createSHA512)

+ (NSString *)createSHA512:(NSString *)source;
- (NSString *)sha1;

@end
