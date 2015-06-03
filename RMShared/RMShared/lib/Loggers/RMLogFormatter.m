//
//  RMLogFormatter.m
//  Romo
//

#import "RMLogFormatter.h"
#import "UIApplication+Environment.h"

#define XCODE_COLORS_ESCAPE @"\033["

#define XCODE_COLORS_RESET_FG  XCODE_COLORS_ESCAPE @"fg;" // Clear any foreground color
#define XCODE_COLORS_RESET_BG  XCODE_COLORS_ESCAPE @"bg;" // Clear any background color
#define XCODE_COLORS_RESET     XCODE_COLORS_ESCAPE @";"   // Clear any foreground or background color

@interface RMLogFormatter ()

@property (nonatomic, strong) NSDateFormatter *dateFormatter;
@property (nonatomic, assign) BOOL colorsEnabled;

@end

@implementation RMLogFormatter

- (id)init
{
    self = [super init];
    
    if (self) {
        _dateFormatter = [[NSDateFormatter alloc] init];
        [self.dateFormatter setDateFormat:@"yyyy-MM-dd HH:mm:ss.SSS"];
    }
    
    return self;
}

- (id)initWithColors:(BOOL)colors
{
    self = [self init];
    
    if (self) {
        _colorsEnabled = colors && [[UIApplication environmentVariableWithKey:@"XcodeColors"] isEqualToString:@"YES"];
        
//#ifdef XCODE_COLORS
//        _colorsEnabled = colors;
//#else
//        _colorsEnabled = NO;
//#endif
    }
    
    return self;
}

- (NSString *)formatLogMessage:(DDLogMessage *)logMessage
{
    static NSString *appName = @"Romo";
    
    NSString *className = logMessage.fileName;
    NSString *dateString = [self.dateFormatter stringFromDate:logMessage->timestamp];
    
    if (self.colorsEnabled) {
        NSString *messageColorEscape = XCODE_COLORS_ESCAPE @"fg0,0,0;";
        
        if (logMessage->logFlag == LOG_FLAG_ERROR) {
            messageColorEscape = XCODE_COLORS_ESCAPE @"fg220,0,0;";
        } else if (logMessage->logFlag == LOG_FLAG_WARN) {
            messageColorEscape = XCODE_COLORS_ESCAPE @"fg255,102,0;";
        }
        
        return [NSString stringWithFormat:XCODE_COLORS_ESCAPE @"fg110,110,110;%@ %@ [%@ %s]:%i" XCODE_COLORS_RESET @" %@%@" XCODE_COLORS_RESET, dateString, appName, className, logMessage->function, logMessage->lineNumber, messageColorEscape, logMessage->logMsg];
    } else {
        return [NSString stringWithFormat:@"%@ %@ [%@ %s]:%i %@", dateString, appName, className, logMessage->function, logMessage->lineNumber, logMessage->logMsg];
    }
}

@end
