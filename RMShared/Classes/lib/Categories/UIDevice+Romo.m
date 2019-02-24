//
//  UIDevice+Romo.m
//  CocoaLumberjack
//
//  Created by Foti Dim on 11.02.19.
//

#import "UIDevice+Romo.h"
#include <sys/socket.h> // Per msqr
#include <sys/sysctl.h>
#include <net/if.h>
#include <net/if_dl.h>

@implementation UIDevice (Romo)

- (BOOL)isiPhone4OrOlder
{
    static BOOL flag = YES;
    static BOOL isiPhone4OrOlder = NO;

    if (flag) {
        flag = NO;

        BOOL isIphone = [self deviceFamily] == UIDeviceFamilyiPhone;
        NSPredicate *iphoneTest = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", @"iPhone[0-3],.*"];
        BOOL isThreeOrOld = [iphoneTest evaluateWithObject:[self modelIdentifier]];
        isiPhone4OrOlder = isIphone && isThreeOrOld;
    }
    return isiPhone4OrOlder;
}

- (BOOL)isOriginaliPad
{
    static BOOL flag = YES;
    static BOOL isiPadOneOrOlder = NO;

    if (flag) {
        flag = NO;

        BOOL isIpad = [self deviceFamily] == UIDeviceFamilyiPad;
        NSPredicate *ipadTest = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", @"iPad[0-1],.*"];
        BOOL isOneOrOld = [ipadTest evaluateWithObject:[self modelIdentifier]];
        isiPadOneOrOlder = isIpad && isOneOrOld;
    }
    return isiPadOneOrOlder;
}

- (BOOL)isiPadThreeOrOlder
{
    static BOOL flag = YES;
    static BOOL isiPadThreeOrOlder = NO;

    if (flag) {
        flag = NO;

        BOOL isIpad = [self deviceFamily] == UIDeviceFamilyiPad;
        NSPredicate *ipadTest = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", @"iPad[0-3],.*"];
        BOOL isThreeOrOlder = [ipadTest evaluateWithObject:[self modelIdentifier]];
        isiPadThreeOrOlder = isIpad && isThreeOrOlder;
    }
    return isiPadThreeOrOlder;
}

- (BOOL)isiPhone4SOrOlder
{
    static BOOL flag = YES;
    static BOOL isiPhone4SOrOlder = NO;

    if (flag) {
        flag = NO;

        BOOL isiPhone = [self deviceFamily] == UIDeviceFamilyiPhone;
        NSPredicate *iphoneTest = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", @"iPhone[0-4],.*"];
        BOOL is4SOrOlder = [iphoneTest evaluateWithObject:[self modelIdentifier]];
        isiPhone4SOrOlder = isiPhone && is4SOrOlder;
    }
    return isiPhone4SOrOlder;
}

- (BOOL)isiPod4OrOlder
{
    static BOOL flag = YES;
    static BOOL isiPod4OrOlder = NO;

    if (flag) {
        flag = NO;

        BOOL isIpod = [self deviceFamily] == UIDeviceFamilyiPod;
        NSPredicate *ipodTest = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", @"iPod[0-4],.*"];
        BOOL is4OrOlder = [ipodTest evaluateWithObject:[self modelIdentifier]];
        isiPod4OrOlder = isIpod && is4OrOlder;
    }
    return isiPod4OrOlder;
}

- (BOOL)isDockableTelepresenceDevice
{
    static BOOL flag = YES;
    static BOOL isDockableTelepresenceDevice = NO;

    if (flag) {
        flag = NO;

        BOOL isiPod = [self deviceFamily] == UIDeviceFamilyiPod;
        BOOL isiPhone = [self deviceFamily] == UIDeviceFamilyiPhone;
        isDockableTelepresenceDevice = (isiPod && [self hasLightningConnector]) || (isiPhone && ![self isiPhone4OrOlder]);
    }
    return isDockableTelepresenceDevice;
}

- (BOOL)isTelepresenceController
{
    static BOOL flag = YES;
    static BOOL isTelepresenceController = NO;

    if (flag) {
        flag = NO;

        BOOL isiPad = [self deviceFamily] == UIDeviceFamilyiPad;
        isTelepresenceController = [self isDockableTelepresenceDevice] || (isiPad && ![self isOriginaliPad]);
    }

    return isTelepresenceController;
}

- (BOOL)isFastDevice
{
    static BOOL flag = YES;
    static BOOL usesRetina = NO;

    if (flag) {
        flag = NO;
        BOOL isRetinaiPad = (([self deviceFamily] == UIDeviceFamilyiPad) && [UIDevice currentDevice].usesRetinaGraphics);
        BOOL isTelepresencePhoneOrPod = [self isDockableTelepresenceDevice];
        usesRetina = isRetinaiPad || isTelepresencePhoneOrPod;
    }
    return usesRetina;
}

- (BOOL)hasLightningConnector
{
    static BOOL flag = YES;
    static BOOL hasLightningConnector = NO;

    if (flag) {
        flag = NO;
        BOOL isiPod = [self deviceFamily] == UIDeviceFamilyiPod;
        BOOL isiPhone = [self deviceFamily] == UIDeviceFamilyiPhone;
        BOOL isiPad = [self deviceFamily] == UIDeviceFamilyiPad;
        hasLightningConnector = (isiPad && ![self isiPadThreeOrOlder]) || (isiPhone && ![self isiPhone4SOrOlder]) || (isiPod && ![self isiPod4OrOlder]);
    }
    return hasLightningConnector;
}

- (BOOL)usesRetinaGraphics
{
    return ([UIScreen mainScreen].scale == 2.0f);
}

- (BOOL)isShortiPod
{
    static BOOL flag = YES;
    static BOOL isShortiPod = NO;

    if (flag) {
        flag = NO;

        BOOL isiPod = self.deviceFamily == UIDeviceFamilyiPod;
        BOOL isShort = [[UIScreen mainScreen] bounds].size.height < 500;
        isShortiPod = isiPod && isShort;
    }
    return isShortiPod;
}

@end
