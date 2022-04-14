#  CMobileDevice

This is the C backend used to communicate with iOS devices. These files are mostly based on the `libimobiledevice` [tools](https://github.com/libimobiledevice/libimobiledevice/tree/master/tools). All files in this folder are published under the [GPL 2 License](COPYRIGHT).

The header `include/mobiledevice.h` is the public API provided by this package. This header export `libimobiledevice/libimobiledevice.h` as well. Use `libimobiledevice` directly to receive a list of all devices. Use the helper functions to interact with the device to change the location or upload the developer disk images.
