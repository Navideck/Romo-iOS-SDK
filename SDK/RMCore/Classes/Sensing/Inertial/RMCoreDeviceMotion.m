//
//  RMCoreDeviceMotion.m
//  RMCore
//

#import "RMCoreDeviceMotion.h"

@implementation RMCoreDeviceMotion

// Unpack data into individual properties for easier external access
- (void)setFreshIMUData:(RMCoreIMUData)freshIMUData
{
    self.accelerometer = freshIMUData.accelerometer;
    self.gyroscope = freshIMUData.gyroscope;
    
    self.deviceAcceleration = freshIMUData.deviceAcceleration;
    self.gravity = freshIMUData.gravity;
    self.rotationRate = freshIMUData.rotationRate;
    self.attitude = freshIMUData.attitude;
}

@end
