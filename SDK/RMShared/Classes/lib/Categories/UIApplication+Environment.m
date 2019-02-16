//
//  UIApplication+Environment.m
//  Romo3
//

#import "UIApplication+Environment.h"

@implementation UIApplication (Environment)

static NSMutableDictionary *defaultValues = nil;

+ (void)setEnvironmentVariableDefaultValue:(NSString *)defaultValue forKey:(NSString *)key
{
    static dispatch_once_t onceToken;

    dispatch_once(&onceToken, ^{
        defaultValues = [NSMutableDictionary dictionary];
    });

    if (defaultValue) {
        defaultValues[key] = defaultValue;
    } else {
        [defaultValues removeObjectForKey:key];
    }
}

#ifdef DEBUG

+ (NSString *)environmentVariableWithKey:(NSString *)key
{
    char *var = getenv([key cStringUsingEncoding:NSUTF8StringEncoding]);

    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *defaultsKey = [NSString stringWithFormat:@"env-%@", key];

    if (var != NULL && strcmp(var, "nil") == 0) {
        [defaults removeObjectForKey:defaultsKey];
        [defaults synchronize];
        return defaultValues[key];
    }
    else if (var != NULL) {
        NSString *value = [NSString stringWithCString:var encoding:NSUTF8StringEncoding];
        [defaults setObject:value forKey:defaultsKey];
        [defaults synchronize];
        return [NSString stringWithCString:var encoding:NSUTF8StringEncoding];
    }
    else {
        if ([defaults stringForKey:defaultsKey]) {
            return [defaults stringForKey:defaultsKey];
        } else {
            return defaultValues[key];
        }
    }
}

#else

+ (NSString *)environmentVariableWithKey:(NSString *)key
{
    return defaultValues[key];
}

#endif

@end