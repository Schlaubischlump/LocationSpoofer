//
//  deviceinfo.c
//  LocationSimulator
//
//  Created by David Klopp on 08.08.19.
//  Copyright © 2019 David Klopp. All rights reserved.
//
// Based on: https://github.com/libimobiledevice/libimobiledevice/blob/master/tools/ideviceinfo.c

#include <stdio.h>
#include <string.h>
#include <errno.h>
#include <stdlib.h>

#include <libimobiledevice/libimobiledevice.h>
#include <libimobiledevice/lockdown.h>
#include "CLogger.h"


/// Get the iOS product version string from the connected device
/// - Parameter udid: iOS device UDID
/// - Return: product version string
const char *deviceProductVersion(const char *udid, enum idevice_options lookup_ops) {
    idevice_t device = NULL;
    idevice_error_t ret = idevice_new_with_options(&device, udid, lookup_ops);
    lockdownd_client_t client = NULL;
    lockdownd_error_t ldret = LOCKDOWN_E_UNKNOWN_ERROR;

    if (ret != IDEVICE_E_SUCCESS) {
        LOG_ERROR("Device \"%s\": Not found.", udid);
        return NULL;
    }

    if (LOCKDOWN_E_SUCCESS != (ldret = lockdownd_client_new(device, &client, "deviceinfo"))) {
        LOG_ERROR("Device \"%s\": Could not connect to lockdownd, error code %d.", udid, ldret);
        idevice_free(device);
        return NULL;
    }

    plist_t node = NULL;
    char *res = NULL;

    if(lockdownd_get_value(client, NULL, "ProductVersion", &node) == LOCKDOWN_E_SUCCESS &&
       node != NULL && plist_get_node_type(node) == PLIST_STRING) {
        plist_get_string_val(node, &res);
        plist_free(node);
        node = NULL;
    }

    lockdownd_client_free(client);
    idevice_free(device);

    return res;
}

/// Get the iOS product name string from the connected device
/// - Parameter udid: iOS device UDID
/// - Return: product name string e.g. iPhone OS, Watch OS, Apple TVOS
const char *deviceProductName(const char *udid, enum idevice_options lookup_ops) {
    idevice_t device = NULL;
    idevice_error_t ret = idevice_new_with_options(&device, udid, lookup_ops);
    lockdownd_client_t client = NULL;
    lockdownd_error_t ldret = LOCKDOWN_E_UNKNOWN_ERROR;

    if (ret != IDEVICE_E_SUCCESS) {
        LOG_ERROR("Device \"%s\": Not found.", udid);
        return NULL;
    }

    if (LOCKDOWN_E_SUCCESS != (ldret = lockdownd_client_new(device, &client, "deviceinfo"))) {
        LOG_ERROR("Device \"%s\": Could not connect to lockdownd, error code %d.", udid, ldret);
        idevice_free(device);
        return NULL;
    }

    plist_t node = NULL;
    char *res = NULL;

    if(lockdownd_get_value(client, NULL, "ProductName", &node) == LOCKDOWN_E_SUCCESS &&
       node != NULL && plist_get_node_type(node) == PLIST_STRING) {
        plist_get_string_val(node, &res);
        plist_free(node);
        node = NULL;
    }

    lockdownd_client_free(client);
    idevice_free(device);

    return res;
}

/// Get the name of the connected iOS device (not the name of the product).
/// - Parameter udid: iOS device UDID
/// - Return: name of the iOS device
const char *deviceName(const char *udid, enum idevice_options lookup_ops) {
    idevice_t device = NULL;
    lockdownd_client_t client = NULL;
    lockdownd_error_t ldret = LOCKDOWN_E_UNKNOWN_ERROR;

    if (IDEVICE_E_SUCCESS != idevice_new_with_options(&device, udid, lookup_ops)) {
        LOG_ERROR("Device \"%s\": Not found.", udid);
        return NULL;
    }

    if (LOCKDOWN_E_SUCCESS != (ldret = lockdownd_client_new(device, &client, "devicename"))) {
        LOG_ERROR("Device \"%s\": Could not connect to lockdownd, error code %d.", udid, ldret);
        idevice_free(device);
        return NULL;
    }

    char* name = NULL;
    if (LOCKDOWN_E_SUCCESS != (ldret = lockdownd_get_device_name(client, &name))) {
        LOG_ERROR("Device \"%s\": Could not get device name, error code %d.", udid, ldret);
    }

    lockdownd_client_free(client);
    idevice_free(device);

    return name;
}
