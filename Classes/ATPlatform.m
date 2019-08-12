// AppTapp Framework
// Copyright 2007 Nullriver, Inc.

#import "ATPlatform.h"

#ifndef INSTALLER_APP
    #import "kali.h"
#endif // INSTALLER_APP

#import <mach-o/ldsyms.h>

static NSString* sDeviceUUID = nil;

@implementation ATPlatform

+ (NSString *)platformName {
#ifdef INSTALLER_APP
	return @"Mac";
#else
	return [UIDevice currentDevice].model;
#endif // INSTALLER_APP
}

+ (NSString *)firmwareVersion {
#ifdef INSTALLER_APP
    return @"2.2";
#else
	return [UIDevice currentDevice].systemVersion;
#endif // INSTALLER_APP
}

+ (NSString *)deviceName {
#ifdef INSTALLER_APP
    return @"Mac";
#else
	return [UIDevice currentDevice].name;
#endif // INSTALLER_APP
}

+ (NSString *)deviceUUID {
	if (!sDeviceUUID)
	{
#if !(__i386__) && !defined(INSTALLER_APP)

#if defined(ATCORE)
	void * kali = kali_start((void *)&_mh_execute_header);
#else
	void * kali = kali_start((void *)&_mh_dylib_header);
#endif
	if (kali != NULL)			// kali failure, bail.
	{
		char deviceID[32] = { 0 };

		if (kali_deviceid_get(kali, KALI_DEVICEID_MAC, deviceID) == 0)
		{
			sDeviceUUID = [[NSString stringWithCString:deviceID] retain];
		}
		else
		{
			exit(1);
		}
	}
	
	kali_stop(kali);
#else
		sDeviceUUID = [@"m000000000000" retain];
#endif
	}
	
	return sDeviceUUID;
}

+ (NSString *)applicationsPath {
	return [@"~/Applications" stringByExpandingTildeInPath];
}

+ (BOOL)isDeviceRootLocked
{
	static BOOL deviceRootLocked = YES;
	static BOOL deviceRootLockedInitialized = NO;
	
	if (deviceRootLockedInitialized)
		return deviceRootLocked;
		
	deviceRootLockedInitialized = YES;
	
	NSError* err = nil;
	
	if ([[NSFileManager defaultManager] createDirectoryAtPath:@"/Library/InstallerTest" withIntermediateDirectories:NO attributes:nil error:&err])
	{
		deviceRootLocked = NO;
		[[NSFileManager defaultManager] removeItemAtPath:@"/Library/InstallerTest" error:nil];
	}
	
	return deviceRootLocked;
}

@end
