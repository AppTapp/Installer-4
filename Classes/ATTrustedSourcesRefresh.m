//
//  ATTrustedSourcesRefresh.m
//  Installer
//
//  Created by Slava Karpenko on 7/30/08.
//  Copyright 2008 RiP Dev. All rights reserved.
//

#import "ATTrustedSourcesRefresh.h"
#import "ATSource.h"
#import "ATPipelineManager.h"
#import "NSURL+AppTappExtensions.h"
#import "ATURLDownload.h"
#import "ATDatabase.h"
#import "ATPackageManager.h"

@implementation ATTrustedSourcesRefresh

@synthesize download;
@synthesize tempFileName;

- (void)dealloc
{
    if (download.delegate == self)
        download.delegate = nil;

	self.download = nil;
	self.tempFileName = nil;
	
	[super dealloc];
}

#pragma mark -
#pragma mark ATSource Protocol

- (NSString*)taskID
{
	return @"trusted.sources";
}

- (NSString*)taskDescription
{
	return NSLocalizedString(@"Refreshing trusted sources", @"");
}

- (double)taskProgress
{
	return -1;
}

- (NSArray*)taskDependencies
{
	return nil;
}

- (void)taskStart
{
	if (gATBehaviorFlags & kATBehavior_NoNetwork)
	{
		[[ATPipelineManager sharedManager] taskDoneWithSuccess:self];
		return;
	}
	
	NSURL* sourceURL = [[NSURL URLWithString:__TRUSTED_SOURCES_LOCATION__] URLWithInstallerParameters];
	 
	self.download = [[[ATURLDownload alloc] initWithRequest:[NSURLRequest requestWithURL:sourceURL] delegate:self] autorelease];
}

#pragma mark -
#pragma mark ATURLDownload delegate

- (void)download:(ATURLDownload *)dl didCreateDestination:(NSString *)path
{
	self.tempFileName = path;
}

- (void)downloadDidFinish:(ATURLDownload *)dl
{
	// do processing
	NSDictionary* trustedSourcesData = [NSDictionary dictionaryWithContentsOfFile:self.tempFileName];
	
	[[NSFileManager defaultManager] removeItemAtPath:self.tempFileName error:nil];
	
	if (trustedSourcesData && [trustedSourcesData objectForKey:@"trusted"] && [trustedSourcesData objectForKey:@"unsafe"])
	{
		[[ATDatabase sharedDatabase] executeUpdate:@"UPDATE sources SET isTrusted = 0"];		// clear trusted flag on all sources

		for (NSString* sourceURL in [trustedSourcesData objectForKey:@"trusted"])
		{
			ATSource* src = [[ATPackageManager sharedPackageManager].sources sourceWithLocation:sourceURL];
			if (src)
			{
				src.isTrusted = [NSNumber numberWithBool:YES];
				[src commit];

				//[[NSNotificationCenter defaultCenter] performSelectorOnMainThread:@selector(postNotification:) withObject:[NSNotification notificationWithName:ATSourceUpdatedNotification object:src userInfo:nil] waitUntilDone:NO];
			}
		}

		for (NSString* sourceURL in [trustedSourcesData objectForKey:@"unsafe"])
		{
			ATSource* src = [[ATPackageManager sharedPackageManager].sources sourceWithLocation:sourceURL];
			if (src)
			{
				[src remove];
				
				//[[NSNotificationCenter defaultCenter] performSelectorOnMainThread:@selector(postNotification:) withObject:[NSNotification notificationWithName:ATSourceUpdatedNotification object:src userInfo:nil] waitUntilDone:NO];
			}
		}

		[[ATPipelineManager sharedManager] taskDoneWithSuccess:self];
	}
	else
	{
		NSError* err = [NSError errorWithDomain:AppTappErrorDomain code:kATErrorTrustedSourcesRefreshFailed userInfo:[NSDictionary dictionaryWithObjectsAndKeys:@"Unable to decode trusted sources info", NSLocalizedDescriptionKey, nil]];
		[[ATPipelineManager sharedManager] taskDoneWithError:self error:err];
	}
}

- (void)download:(ATURLDownload *)dl didFailWithError:(NSError *)error
{
	[[ATPipelineManager sharedManager] taskDoneWithError:self error:error];
}

@end
