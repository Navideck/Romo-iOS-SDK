//
//  RMLogFormatter.h
//  Romo
//

#import <Foundation/Foundation.h>
#import <CocoaLumberjack/CocoaLumberjack.h>

@interface RMLogFormatter : NSObject <DDLogFormatter>

- (id)initWithColors:(BOOL)colors;

@end
