// AppTapp Framework
// Copyright 2007 Nullriver, Inc.

#import "NSURL+AppTappExtensions.h"
#import "NSString+AppTappExtensions.h"
#import "ATPlatform.h"

@implementation NSURL (AppTappExtensions)

- (BOOL)isEqualToURL:(NSURL *)aURL {
	if([[self comparableStringValue] isEqualToString:[aURL comparableStringValue]]) return YES;
	else return NO;
}

- (NSString *)comparableStringValue {
	return [[[self standardizedURL] absoluteString] stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"/"]];
}

- (NSURL *)URLWithInstallerParameters {
	if (![[self standardizedURL] absoluteString])
		return nil;
		
	NSMutableString* newURLString = [NSMutableString stringWithString:[[self standardizedURL] absoluteString]];
	
	if (![self query] || ![[self query] length])
	{
		[newURLString appendString:@"?"];
	}

	NSMutableDictionary* installerParams = [NSMutableDictionary dictionaryWithCapacity:0];
	
    NSString* objectString = [ATPlatform deviceUUID];
    if (objectString != nil)
        [installerParams setObject:objectString forKey:@"deviceUUID"];

    objectString = [ATPlatform platformName];
    if (objectString != nil)
        [installerParams setObject:objectString forKey:@"platform"];

    objectString = [ATPlatform firmwareVersion];
    if (objectString != nil)
        [installerParams setObject:objectString forKey:@"firmwareVersion"];

	[installerParams setObject:__INSTALLER_VERSION__ forKey:@"installerVersion"];
	
	NSArray* languages = [NSLocale preferredLanguages];
	
	if (languages && [languages count])
		[installerParams setObject:[languages objectAtIndex:0] forKey:@"locale"];
		
	for (NSString* key in installerParams)
	{
		[newURLString appendFormat:@"&%@=%@", [key stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding], [[installerParams objectForKey:key] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
	}

	//Log(@"url = %@", newURLString);
	
	return [NSURL URLWithString:newURLString];
}

- (NSString*)tempDownloadFileName
{
	NSString* hash = [[self absoluteString] MD5Hash];
	NSString* path = [NSString stringWithFormat:@"%@#%.0f", hash, [[NSDate date] timeIntervalSinceReferenceDate]];
	
	//Log(@"temp name for %@: %@", self, path);
	return path;
}

@end
