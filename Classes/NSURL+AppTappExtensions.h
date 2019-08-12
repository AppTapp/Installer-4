// AppTapp Framework
// Copyright 2007 Nullriver, Inc.


@interface NSURL (AppTappExtensions)

- (BOOL)isEqualToURL:(NSURL *)aURL;
- (NSString *)comparableStringValue;
- (NSURL *)URLWithInstallerParameters;

- (NSString*)tempDownloadFileName;

@end
