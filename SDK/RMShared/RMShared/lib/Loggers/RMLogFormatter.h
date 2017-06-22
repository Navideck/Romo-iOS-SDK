//
//  RMLogFormatter.h
//  Romo
//

#import <Foundation/Foundation.h>

@interface RMLogFormatter : NSObject <DDLogFormatter>

- (id)initWithColors:(BOOL)colors;

@end
