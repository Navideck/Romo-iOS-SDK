//
//  RMVisionObjectTrackingModuleDebug.m
//  RMVision
//
//  Created on 11/17/13.
//  Copyright (c) 2013 Romotive, Inc. All rights reserved.
//

#import "RMVisionObjectTrackingModuleDebug.h"
#import "RMVideoModule.h"
#include <NMSSH/NMSSH.h>

#define kDataFolder       @"RMVisionObjectTrackingDebugData"
#define kTrainingData     @"RMVisionTrainingData.data"

@interface RMVisionObjectTrackingModuleDebug()

@property (nonatomic, weak) RMVisionObjectTrackingModule *module;
@property (nonatomic, strong) NSString *saveToFolder;
@property (nonatomic, strong) RMVideoModule *videoModule;
@property (nonatomic, strong) NSString *videoPath;

@end

@implementation RMVisionObjectTrackingModuleDebug

-(id)initWithModule:(RMVisionObjectTrackingModule *)module
{
    self = [super init];
    if (self) {
        _module = module;
    }
    
    return self;
}


#pragma mark - Start/Stop

-(BOOL)startDebugCapture
{
    if (![self createDataFolder]) {
        return NO;
    }

    self.videoPath = [[self.saveToFolder stringByAppendingPathComponent:@"inputVideo"] stringByAppendingString:@".mp4"];
    
     self.videoModule = [[RMVideoModule alloc] initWithVision:self.module.vision recordToPath:self.videoPath];
    [self.module.vision activateModule:self.videoModule];
    
    BOOL successFlag = [self.module.vision.activeModules containsObject:self.videoModule];
    
    successFlag |= [self saveTrainingData];
    
    return successFlag;
}

-(BOOL)stopDebugCaptureWithCompletion:(void(^)(NSData *compressedData))callback
{
    
    
    [self.module.vision deactivateModule:self.videoModule];

    [self.videoModule shutdownWithCompletion:^{
        
        NSError *error = nil;

        NMSSHSession *sshSession = [self connectToSSH];

        NSString *remoteFilePath = [ @[kDataFolder, [self getDateString]] componentsJoinedByString:@"/"];
        
        // Make the remove directory
        NSString *command = [@"mkdir -p " stringByAppendingString:remoteFilePath];
        NSString *response = [sshSession.channel execute:command error:&error];
        NSLog(@"Response: %@", response);
        
        // List files in the local directory
        NSArray *files = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:self.saveToFolder error:&error];
        if (files == nil) {
            NSLog(@"Error reading contents of documents directory: %@", [error localizedDescription]);
        }
        
        // Upload all the files in the local directory
        BOOL success = YES;
        for (NSString *file in files) {
            
            NSString *localFile = [@[self.saveToFolder, file] componentsJoinedByString:@"/"];
            NSString *remoteFile = [@[remoteFilePath, file] componentsJoinedByString:@"/"];

            NSLog(@"%@ -> %@", localFile, remoteFile);

            success &= [sshSession.channel uploadFile:localFile
                                                   to:remoteFile];
        }
        
        if (!success) {
            NSLog(@"Upload failed");
            // If upload failed, save the file locally
        }
        else {
            NSLog(@"Upload successful!");
            [self deleteDataFolder];
        }
        
        [sshSession disconnect];
    
    }];
    
    return YES;
}

#pragma mark - File system helpers
- (BOOL)createDataFolder
{
    NSString *documentsDirectory = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    
    self.saveToFolder = @"";
    self.saveToFolder = [documentsDirectory stringByAppendingPathComponent:kDataFolder];
    self.saveToFolder = [self.saveToFolder stringByAppendingPathComponent:[self getDateString]];

    
    NSError *error;
    BOOL successFlag = [[NSFileManager defaultManager] createDirectoryAtPath:self.saveToFolder withIntermediateDirectories:YES attributes:nil error:&error];
    
    if (!successFlag) {
        NSLog(@"Error creating data path: %@", [error localizedDescription]);
    }
    return successFlag;
    
}

-(BOOL)deleteDataFolder
{
    NSError *error;
    BOOL successFlag = [[NSFileManager defaultManager] removeItemAtPath:self.saveToFolder error:&error];
    if (!successFlag) {
        NSLog(@"Error removing data path: %@", error.localizedDescription);
    }
    
    return successFlag;
}

#pragma mark - Training data
-(BOOL)saveTrainingData
{
    RMVisionTrainingData *trainingData = [self.module copyOfTrainingData];
    
    // Create encoders
    NSMutableData *encodeData = [[NSMutableData alloc] init];
    NSKeyedArchiver *archiver = [[NSKeyedArchiver alloc] initForWritingWithMutableData:encodeData];
    
    // Encode
    [trainingData encodeWithCoder:archiver];
    [archiver finishEncoding];
    
    
    // Save to the file system
    NSString *path = [self.saveToFolder stringByAppendingString:@"/"];
    path = [path stringByAppendingString:kTrainingData];

    BOOL successFlag = [encodeData writeToFile:path atomically:YES];
    
    if (!successFlag) {
        NSLog(@"Failed to write training data to: %@", path);
    }
    
    return successFlag;

}

#pragma mark - Helper methods

-(NSString *)getDateString
{
    NSDate *now = [NSDate date];
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"yyyy-MM-dd-HH-mm-ss"];
    NSString *dateString = [dateFormatter stringFromDate:now];
    
    return dateString;
}

- (NMSSHSession *)connectToSSH
{
    NMSSHSession *session = [NMSSHSession connectToHost:@"url"
                                           withUsername:@"romo"];
    
    if (session.isConnected) {
        [session authenticateByPassword:@"test"];
                
        if (session.isAuthorized) {
            NSLog(@"Authentication succeeded");
            
            return session;
        }
    }
    
    return nil;
}

@end
