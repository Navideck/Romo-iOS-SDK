//
//  UIApplication+Environment.h
//  Romo
//

#import <UIKit/UIKit.h>

@interface UIApplication (Environment)

+ (void)setEnvironmentVariableDefaultValue:(NSString *)defaultValue forKey:(NSString *)key;
+ (NSString *)environmentVariableWithKey:(NSString *)key;

@end
