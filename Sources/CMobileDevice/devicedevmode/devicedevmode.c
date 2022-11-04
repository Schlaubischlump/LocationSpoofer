//
//  deviceinfo.c
//  LocationSimulator
//
//  Created by David Klopp on 08.08.19.
//  Copyright © 2019 David Klopp. All rights reserved.
//
// Based on: https://gist.github.com/nikias/262bd709c1651e0139eb9e3a2e2d33f4

#include <stdio.h>
#include <string.h>
#include <errno.h>
#include <stdlib.h>
#include <stdbool.h>

#include <libimobiledevice/libimobiledevice.h>
#include <libimobiledevice/lockdown.h>
#include <libimobiledevice/property_list_service.h>
#include "CLogger.h"

#define AMFI_LOCKDOWN_SERVICE_NAME "com.apple.amfi.lockdown"

#define DEV_ACTION_REVEAL 0 // 0 = reveal toggle in settings
#define DEV_ACTION_ENABLE 1 // 1 = enable developer mode (only if no passcode is set)
#define DEV_ACTION_PROMPT 2 // 2 = answers developer mode enable prompt post-restart

/// Get the status of developer mode.
/// - Parameter udid: iOS device UDID
/// - Return: true on success, false otherwise.
bool developerModeIsEnabledForDevice(const char *udid, enum idevice_options lookup_ops) {
    idevice_t device = NULL;
    idevice_error_t ret = idevice_new_with_options(&device, udid, lookup_ops);
    lockdownd_client_t client = NULL;
    lockdownd_error_t ldret = LOCKDOWN_E_UNKNOWN_ERROR;

    if (ret != IDEVICE_E_SUCCESS) {
        LOG_ERROR("Device \"%s\": Not found.", udid);
        return false;
    }

    if (LOCKDOWN_E_SUCCESS != (ldret = lockdownd_client_new_with_handshake(device, &client, "devmode"))) {
        LOG_ERROR("Device \"%s\": Could not connect to lockdownd, error code %d.", udid, ldret);
        idevice_free(device);
        return false;
    }

    plist_t node = NULL;
    uint8_t dev_mode_status = 0;

    if(LOCKDOWN_E_SUCCESS != (ldret = lockdownd_get_value(client, "com.apple.security.mac.amfi", "DeveloperModeStatus", &node))) {
        LOG_ERROR("Device \"%s\": Could not connect to service com.apple.security.mac.amfi, error code %d.", udid, ldret);
    }

    if (node != NULL && plist_get_node_type(node) == PLIST_BOOLEAN) {
        plist_get_bool_val(node, &dev_mode_status);
        plist_free(node);
        node = NULL;
    } else {
        LOG_ERROR("Device \"%s\": Could not read developer mode status!", udid);
        return false;
    }

    lockdownd_client_free(client);
    idevice_free(device);

    return dev_mode_status;
}

// Enable Developer mode toggle in the settings app.
/// - Parameter udid: iOS device UDID
/// - Return: true on success, false otherwise.
bool enableDeveloperMode(const char *udid, enum idevice_options lookup_ops) {
    bool res = false;
    idevice_t device = NULL;
    idevice_error_t ret = idevice_new_with_options(&device, udid, lookup_ops);
    
    lockdownd_client_t client = NULL;
    lockdownd_error_t ldret = LOCKDOWN_E_UNKNOWN_ERROR;
    lockdownd_service_descriptor_t service = NULL;
    
    property_list_service_error_t perr;
    property_list_service_client_t amfi = NULL;

    if (IDEVICE_E_SUCCESS != ret) {
        LOG_ERROR("Device \"%s\": Not found.", udid);
        goto leave;
    }

    if (LOCKDOWN_E_SUCCESS != (ldret = lockdownd_client_new_with_handshake(device, &client, "devmode"))) {
        LOG_ERROR("Device \"%s\": Could not connect to lockdownd, error code %d.", udid, ldret);
        goto leave;
    }
    
    if (LOCKDOWN_E_SUCCESS != (ldret = lockdownd_start_service(client, AMFI_LOCKDOWN_SERVICE_NAME, &service))) {
        LOG_ERROR("Device \"%s\": Could not start amfi service, error code %d!", udid, ldret);
        goto leave;
    }
    
    if (PROPERTY_LIST_SERVICE_E_SUCCESS != (perr = property_list_service_client_new(device, service, &amfi))) {
        LOG_ERROR("Device \"%s\": Could not connect to amfi service, error code %d!", udid, perr);
        goto leave;
    }
    
    plist_t dict = plist_new_dict();
    plist_dict_set_item(dict, "action", plist_new_uint(DEV_ACTION_REVEAL));
    
    if (PROPERTY_LIST_SERVICE_E_SUCCESS != (perr = property_list_service_send_xml_plist(amfi, dict))) {
        LOG_ERROR("Device \"%s\": Failed to enable developer mode, error code %d!", udid, perr);
        goto leave;
    }

    dict = NULL;
    if (PROPERTY_LIST_SERVICE_E_SUCCESS != (perr = property_list_service_receive_plist(amfi, &dict))) {
        LOG_ERROR("Device \"%s\": Failed to receive developer mode reply, error code %d!", udid, perr);
        goto leave;
    }

    uint8_t success = 0;
    plist_t val = plist_dict_get_item(dict, "Error");
    if (val) {
        char* err = NULL;
        plist_get_string_val(val, &err);
        LOG_ERROR("Device \"%s\": Could not enable developer mode: %s!", udid, err);
    } else {
        val = plist_dict_get_item(dict, "success");
        if (val) {
            plist_get_bool_val(val, &success);
            if (!success) {
                LOG_ERROR("Device \"%s\": Could not enable developer mode!", udid);
            } else {
                res = true;   
            }
        }
    }

leave:
    if (service) lockdownd_service_descriptor_free(service);
    if (amfi) property_list_service_client_free(amfi);
    if (client) lockdownd_client_free(client);
    if (dict) plist_free(dict);
    idevice_free(device);

    return res;
}
