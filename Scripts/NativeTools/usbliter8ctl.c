#include <CoreFoundation/CoreFoundation.h>
#include <IOKit/IOCFPlugIn.h>
#include <IOKit/IOKitLib.h>
#include <IOKit/usb/IOUSBLib.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define APPLE_VENDOR_ID 0x05AC
#define DFU_PRODUCT_ID  0x1227
#define DFU_DNLOAD      1
#define DFU_ABORT       4
#define CUSTOM_DEMOTE   7
#define CUSTOM_BOOT     8
#define TRANSFER_SIZE   0x800

static void put_u16(CFMutableDictionaryRef dict, const char *key, int value) {
    CFNumberRef number = CFNumberCreate(kCFAllocatorDefault, kCFNumberIntType, &value);
    if (number) {
        CFDictionarySetValue(dict, CFStringCreateWithCStringNoCopy(kCFAllocatorDefault, key, kCFStringEncodingUTF8, kCFAllocatorNull), number);
        CFRelease(number);
    }
}

static char *copy_registry_string(io_service_t service, const char *key) {
    CFStringRef cfKey = CFStringCreateWithCString(kCFAllocatorDefault, key, kCFStringEncodingUTF8);
    if (!cfKey) {
        return NULL;
    }

    CFTypeRef value = IORegistryEntryCreateCFProperty(service, cfKey, kCFAllocatorDefault, 0);
    CFRelease(cfKey);
    if (!value || CFGetTypeID(value) != CFStringGetTypeID()) {
        if (value) {
            CFRelease(value);
        }
        return NULL;
    }

    CFIndex length = CFStringGetMaximumSizeForEncoding(CFStringGetLength(value), kCFStringEncodingUTF8) + 1;
    char *buffer = calloc((size_t)length, 1);
    if (buffer && !CFStringGetCString(value, buffer, length, kCFStringEncodingUTF8)) {
        free(buffer);
        buffer = NULL;
    }
    CFRelease(value);
    return buffer;
}

static int open_pwndfu_device(IOUSBDeviceInterface ***device_out) {
    CFMutableDictionaryRef matching = IOServiceMatching(kIOUSBDeviceClassName);
    if (!matching) {
        fprintf(stderr, "unable to create USB matching dictionary\n");
        return 1;
    }
    put_u16(matching, kUSBVendorID, APPLE_VENDOR_ID);
    put_u16(matching, kUSBProductID, DFU_PRODUCT_ID);

    io_iterator_t iterator = IO_OBJECT_NULL;
    kern_return_t kr = IOServiceGetMatchingServices(kIOMasterPortDefault, matching, &iterator);
    if (kr != KERN_SUCCESS) {
        fprintf(stderr, "unable to scan USB devices: 0x%08x\n", kr);
        return 1;
    }

    io_service_t service;
    while ((service = IOIteratorNext(iterator)) != IO_OBJECT_NULL) {
        char *serial = copy_registry_string(service, "USB Serial Number");
        if (!serial) {
            serial = copy_registry_string(service, "Serial Number");
        }

        if (!serial || strstr(serial, "PWND:[") == NULL) {
            if (serial) {
                free(serial);
            }
            IOObjectRelease(service);
            continue;
        }
        free(serial);

        IOCFPlugInInterface **plugin = NULL;
        SInt32 score = 0;
        kr = IOCreatePlugInInterfaceForService(service, kIOUSBDeviceUserClientTypeID, kIOCFPlugInInterfaceID, &plugin, &score);
        IOObjectRelease(service);
        if (kr != KERN_SUCCESS || !plugin) {
            fprintf(stderr, "unable to create USB plugin: 0x%08x\n", kr);
            continue;
        }

        IOUSBDeviceInterface **device = NULL;
        HRESULT result = (*plugin)->QueryInterface(plugin, CFUUIDGetUUIDBytes(kIOUSBDeviceInterfaceID), (LPVOID *)&device);
        IODestroyPlugInInterface(plugin);
        if (result || !device) {
            fprintf(stderr, "unable to create USB device interface: 0x%08x\n", (unsigned int)result);
            continue;
        }

        kr = (*device)->USBDeviceOpen(device);
        if (kr != KERN_SUCCESS && kr != kIOReturnExclusiveAccess) {
            fprintf(stderr, "unable to open USB device: 0x%08x\n", kr);
            (*device)->Release(device);
            continue;
        }

        IOObjectRelease(iterator);
        *device_out = device;
        return 0;
    }

    IOObjectRelease(iterator);
    fprintf(stderr, "no PWND DFU device found\n");
    return 1;
}

static IOReturn control_transfer(IOUSBDeviceInterface **device, UInt8 request, UInt16 value, UInt16 index, void *data, UInt16 length) {
    IOUSBDevRequest req;
    memset(&req, 0, sizeof(req));
    req.bmRequestType = 0x21;
    req.bRequest = request;
    req.wValue = value;
    req.wIndex = index;
    req.wLength = length;
    req.pData = data;
    return (*device)->DeviceRequest(device, &req);
}

static int boot_file(const char *path) {
    FILE *file = fopen(path, "rb");
    if (!file) {
        perror("unable to open boot file");
        return 1;
    }

    if (fseek(file, 0, SEEK_END) != 0) {
        perror("unable to seek boot file");
        fclose(file);
        return 1;
    }
    long size = ftell(file);
    if (size <= 0) {
        fprintf(stderr, "boot file is empty\n");
        fclose(file);
        return 1;
    }
    rewind(file);

    unsigned char *buffer = malloc((size_t)size);
    if (!buffer) {
        fprintf(stderr, "unable to allocate boot buffer\n");
        fclose(file);
        return 1;
    }
    if (fread(buffer, 1, (size_t)size, file) != (size_t)size) {
        perror("unable to read boot file");
        free(buffer);
        fclose(file);
        return 1;
    }
    fclose(file);

    IOUSBDeviceInterface **device = NULL;
    int open_result = open_pwndfu_device(&device);
    if (open_result != 0) {
        free(buffer);
        return open_result;
    }

    long offset = 0;
    while (offset < size) {
        UInt16 chunk = (UInt16)((size - offset) > TRANSFER_SIZE ? TRANSFER_SIZE : (size - offset));
        IOReturn kr = control_transfer(device, DFU_DNLOAD, 0, 0, buffer + offset, chunk);
        if (kr != KERN_SUCCESS) {
            fprintf(stderr, "\nUSBError: DFU_DNLOAD failed at 0x%lx: 0x%08x\n", offset, kr);
            (*device)->USBDeviceClose(device);
            (*device)->Release(device);
            free(buffer);
            return 1;
        }

        offset += chunk;
        printf("\rsent - 0x%lx", offset);
        fflush(stdout);
    }
    printf("\n");

    IOReturn kr = control_transfer(device, DFU_DNLOAD, 0, 0, NULL, 0);
    if (kr != KERN_SUCCESS) {
        fprintf(stderr, "USBError: final DFU_DNLOAD failed: 0x%08x\n", kr);
        (*device)->USBDeviceClose(device);
        (*device)->Release(device);
        free(buffer);
        return 1;
    }

    kr = control_transfer(device, CUSTOM_BOOT, 0, 0, NULL, 0);
    if (kr != KERN_SUCCESS) {
        fprintf(stderr, "USBError: CUSTOM_BOOT failed: 0x%08x\n", kr);
        (*device)->USBDeviceClose(device);
        (*device)->Release(device);
        free(buffer);
        return 1;
    }

    control_transfer(device, DFU_ABORT, 0, 0, NULL, 0);
    (*device)->USBDeviceClose(device);
    (*device)->Release(device);
    free(buffer);
    return 0;
}

static int demote_device(void) {
    IOUSBDeviceInterface **device = NULL;
    int open_result = open_pwndfu_device(&device);
    if (open_result != 0) {
        return open_result;
    }

    IOReturn kr = control_transfer(device, CUSTOM_DEMOTE, 0, 0, NULL, 0);
    (*device)->USBDeviceClose(device);
    (*device)->Release(device);
    if (kr != KERN_SUCCESS) {
        fprintf(stderr, "USBError: CUSTOM_DEMOTE failed: 0x%08x\n", kr);
        return 1;
    }
    return 0;
}

static void usage(const char *argv0) {
    fprintf(stderr, "usage: %s boot <iboot.raw>\n       %s demote\n", argv0, argv0);
}

int main(int argc, char **argv) {
    if (argc == 2 && (strcmp(argv[1], "--help") == 0 || strcmp(argv[1], "-h") == 0)) {
        usage(argv[0]);
        return 0;
    }

    if (argc >= 2 && strcmp(argv[1], "boot") == 0) {
        if (argc != 3) {
            usage(argv[0]);
            return 2;
        }
        return boot_file(argv[2]);
    }

    if (argc == 2 && strcmp(argv[1], "demote") == 0) {
        return demote_device();
    }

    usage(argv[0]);
    return 2;
}
