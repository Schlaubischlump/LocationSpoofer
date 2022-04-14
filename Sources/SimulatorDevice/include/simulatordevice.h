//
//  simulatordevice.h
//  LocationSimulator
//
//  Created by David Klopp on 13.03.21.
//  Copyright © 2021 David Klopp. All rights reserved.
//

#ifndef simulatordevice_h
#define simulatordevice_h

#import <Foundation/Foundation.h>

@interface SimDeviceWrapper : NSObject

/**
 A list with all avaiable devices.
 */
+ (NSMutableSet* _Nullable)availableDevices;

/**
 Call the handler for every currently connected simulator device and observe the simulator devices to call the handler
 again if a new device is connected or disconnected.
 - Paramater handler: the callback handler to perform
 - Return: the id of the notification subscriber
 */
+ (NSUInteger)subscribe:(void (^ _Nonnull)(SimDeviceWrapper * _Nonnull))handler;
/**
 Stop listening for device connect and disconnect events.
 - Paramater handlerID: the id of the notification handler
 - Return: True on success, false otherwise
 */
+ (BOOL)unsubscribe:(NSUInteger)handlerID;
/**
 The udid of this simulator device.
 */
- (NSString * _Nonnull)udid;
/**
 The name of this simulator device.
 */
- (NSString * _Nonnull)name;

/**
 The product name e.g. iPhone OS
 */
- (NSString * _Nullable)productName;

/**
 The product version e.g. iOS 15.4
 */
- (NSString * _Nullable)productVersion;

/**
 Indicate if the location of this device can be spoofed.
 - Return: True if the location can be spoofed, False otherwise.
 */
- (BOOL)isConnected;
/**
 Change the current device location to a new location.
 - Parameter latitude: the new latitude
 - Parameter longitude: the new longitude
 - Return: True if the location could be changed, False otherwise.
 */
- (BOOL)setLocationWithLatitude:(double)latitude andLongitude:(double)longitude;
/**
This stops the simulation spoofing. For Xcode <= 12.4 this is a NOP.
 - Return: True if the location was reset, False otherwise.
 */
- (BOOL)resetLocation;
@end


#endif /* simulatordevice_h */
