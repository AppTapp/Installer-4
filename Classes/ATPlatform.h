// AppTapp Framework
// Copyright 2007 Nullriver, Inc.


@interface ATPlatform : NSObject {
}

+ (NSString *)platformName;
+ (NSString *)firmwareVersion;
+ (NSString *)deviceName;
+ (NSString *)deviceUUID;
+ (NSString *)applicationsPath;
+ (BOOL)isDeviceRootLocked;

@end
