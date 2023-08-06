# LocationSpoofer

> **Note**:   
> Currently you should make sure to initialize a [c-logger](https://github.com/Schlaubischlump/CLogger.git) instance (console logging is sufficient e.g `logger_initConsoleLogger(nil)`) before attempting to use the library. I'll try to change this in the future.

### Description

This package provides a simple wrapper around `libimobiledevice` and some internal Apple APIs in `CoreSimulator` to allow spoofing the location of iOS devices or iPhoneSimulator devices. To use the SimulatorDevice API inside a sandboxed application make sure to add your application to the app group "com.apple.CoreSimulator". 

### Structure

There are two main classes: `IOSDevice` and `SimualtorDevice`. Use the `IOSDevice` class if you want to interact with real devices. Use `SimualtorDevice` when interacting with the iPhoneSimulator. Both classes conform to the `Device` interface. For simple location spoofing cases you can use these classes directly. The `Device` interface defines all necessary functions to set and reset the current location.   
  
For more complex location manipulation this packages includes the `LocationSpoofer` class. This class is initialized with a device instance and allows you to automatically update the location based on specific criteria.

### List devices

You can either list all available devices using: 

```Swift
let iosDevices: [Device] = IOSDevice.availableDevices
let simDevices: [Device] = SimulatorDevice.availableDevices
```

or you can listen for new devices. To start/stop the listening process use:

```Swift
IOSDevice.startGeneratingDeviceNotifications()
SimulatorDevice.startGeneratingDeviceNotifications()
...
// If you don't need updates anymore
IOSDevice.stopGeneratingDeviceNotifications()
SimulatorDevice.stopGeneratingDeviceNotifications()
```

To respond to the notifications, register a notification observer and bind it to a function: 

```Swift
// You can also use: .DeviceChanged, .DevicePaired or .DeviceDisconnected
NotificationCenter.default.addObserver(self, selector: #selector(deviceConnected), name: .DeviceConnected, object: nil)

@objc func deviceConnected(_ notification: Notification) {
	let device = notification.userInfo?["device"] as? Device
	...
}
```

### Location change

You can then directly interact with the device. You can change the current location by using:

```Swift
// Change the location
let destination = CLLocationCoordinate2D(latitude: 1000, longitude: 1000)
device.simulateLocation(destination)

// Stop spoofing
device.disableSimulation()
```

### LocationSpoofer

To initialize a `LocationSpoofer` instance use:

```Swift
let spoofer = LocationSpoofer(device)
// Configure some basic parameters
spoofer.heading = 90       // degree
spoofer.speed = 5          // m/s
spoofer.moveType = .drive  
```

The LocationSpoofer has three different movement states:    
**1. manual**: Manually set the location   
**2. auto**: Move in the direction of `heading`   
**3. navigation(route: NavigationRoute)**: Follow a route

Each movement state can toggle between automatic updates and manual updates. Depending on the move state automatic updates behave differently.

| moveState | manual update behaviour | auto update behaviour | supports `setLocation` |
|---|---|---|---|
|manual|move in the direction of heading with speed|periodically, randomly move when no user input is provided to fake GPS uncertainty| yes |
|auto|move in the direction of heading with speed|automatically move in the direction of heading with speed| no |
|navigation(route: NavigationRoute)|follow along the route coordinates|automatically follow along the route coordinates| no |

##### Manual update

To manually perform the move action, set the `moveState` and call the `move` function. When updating manually, `manual` and `auto` behave almost the same. The only difference is, that you can use `setLocation` to explicitly set a new location, when the `moveState` is set to `manual`.

```Swift
// Move in the direction of heading with a specific speed
spoofer.moveState = .auto
spoofer.move()

// This behaves the same as in auto
spoofer.moveState = .manual
spoofer.move() 

// Manually change the location to a specific coordinate
let destination = CLLocationCoordinate2D(latitude: 1000, longitude: 1000)
spoofer.setLocation(destination)

// Define a navigation
let route: [CLLocationCoordinate2D] = [...]
spoofer.moveState = .navigation(route: NavigationRoute(route)) 
// Move to the first coordinate
spoofer.move()
// Wait
sleep(1)
// Move to the second coordinate
spoofer.move()
```

##### Automatic update

With automatic updates, `LocationSpoofer` will periodically update the location for you. To activate auto update in `manual` or `auto` state `LocationSpoofer` will need a current location. Therefore always set a previous location with `setLocation` before trying to activate auto update in one of these states.

```Swift
// Define a navigation
let route: [CLLocationCoordinate2D] = [...]
spoofer.moveState = .navigation(route: NavigationRoute(route)) 
// Automatically update the location based on speed and the device responds time
// to follow along the route.
spoofer.startAutoUpdate()
...
// Stop the automatic update
spoofer.stopAutoUpdate()


// You can still set a new location or call move when in auto update mode with
// manual moveState. This auto update in manual state will just randomly, 
// slightly change your location, if you do not provide any input.
spoofer.moveState = .manual
spoofer.startAutoUpdate()

```

##### Delegate

To get informed about location changes performed by `LocationSpoofer` you can implement the `LocationSpooferDelegate`. It provides the following methods: 

```Swift
// MoveType
func willChangeMoveType(spoofer: LocationSpoofer, toMoveType: MoveType)
func didChangeMoveType(spoofer: LocationSpoofer, fromMoveType: MoveType)
// MoveState
func willChangeMoveState(spoofer: LocationSpoofer, toMoveState: MoveState)
func didChangeMoveState(spoofer: LocationSpoofer, fromMoveState: MoveState)
// Auto update
func willChangeAutoUpdate(spoofer: LocationSpoofer, toValue: Bool)
func didChangeAutoUpdate(spoofer: LocationSpoofer, fromValue: Bool)
// Location (nil in case of a location reset)
func willChangeLocation(spoofer: LocationSpoofer, toCoordinate: CLLocationCoordinate2D?)
func didChangeLocation(spoofer: LocationSpoofer, toCoordinate: CLLocationCoordinate2D?)
func errorChangingLocation(spoofer: LocationSpoofer, toCoordinate: CLLocationCoordinate2D?)
```
