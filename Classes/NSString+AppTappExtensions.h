// AppTapp Framework
// Copyright 2007 Nullriver, Inc.


#import "ATPlatform.h"

@interface NSString (AppTappExtensions)

- (NSString *)stringByRemovingPathPrefix:(NSString *)pathPrefix;
- (BOOL)isContainedInPath:(NSString *)aPath;
- (NSString *)stringByExpandingSpecialPathsInPath;
- (NSString*)sqliteEscapedString;

- (unsigned long long)versionNumber;

- (NSString *)MD5Hash;

@end
