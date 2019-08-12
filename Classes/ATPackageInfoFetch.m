//
//  ATPackageInfoFetch.m
//  Installer
//
//  Created by Slava Karpenko on 7/11/08.
//  Copyright 2008 RiP Dev. All rights reserved.
//

#import "ATPackageManager.h"
#import "ATPackageInfoFetch.h"
#import "ATPackage.h"
#import "ATPipelineManager.h"
#import "NSURL+AppTappExtensions.h"
#import "ATURLDownload.h"
#import "ATDatabase.h"

@implementation ATPackageInfoFetch

@synthesize package;
@synthesize download;
@synthesize tempFileName;

- initWithPackage:(ATPackage*)pack
{
	if (self = [super init])
	{
		self.package = pack;
	}
	
	return self;
}

- (void)dealloc
{
	[self.download cancel];
    if (download.delegate == self)
        download.delegate = nil;

	self.package = nil;
	self.download = nil;
	self.tempFileName = nil;

	[super dealloc];
}

#pragma mark -
#pragma mark ATSource Protocol

- (NSString*)taskID
{
	return [NSString stringWithFormat:@"info:%@", self.package.identifier];
}

- (NSString*)taskDescription
{
	return [NSString stringWithFormat:NSLocalizedString(@"Fetching info for %@...", @""), self.package.name];
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
	NSURL* sourceURL = [self.package.moreURL URLWithInstallerParameters];

	if ((gATBehaviorFlags & kATBehavior_NoNetwork) || sourceURL == nil)
	{
		[[ATPipelineManager sharedManager] taskDoneWithSuccess:self];
		return;
	}

    [[NSNotificationCenter defaultCenter] performSelectorOnMainThread:@selector(postNotification:) withObject:[NSNotification notificationWithName:ATPackageInfoFetchingNotification object:self.package userInfo:nil] waitUntilDone:NO];
    
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
	NSDictionary* dict = [NSDictionary dictionaryWithContentsOfFile:self.tempFileName];
	
	[[NSFileManager defaultManager] removeItemAtPath:self.tempFileName error:nil];
	
	if (!dict)
	{
		NSError* err = [NSError errorWithDomain:AppTappErrorDomain code:kATErrorPackageInfoDecodeFailed userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[NSString stringWithFormat:@"Unable to decode package more info at %@", self.package.moreURL], NSLocalizedDescriptionKey,
																																							self.package.identifier, @"packageID", nil]];
		[[ATPipelineManager sharedManager] taskDoneWithError:self error:err];
		return;
	}
	
	self.package.description = [dict objectForKey:@"description"];
	self.package.hash = [dict objectForKey:@"hash"];
	self.package.location = [dict objectForKey:@"location"];
	self.package.size = [dict objectForKey:@"size"];
	self.package.sponsor = [dict objectForKey:@"sponsor"];
	self.package.sponsorURL = [dict objectForKey:@"sponsorURL"];
	self.package.maintainer = [dict objectForKey:@"maintainer"];
	self.package.contact = [dict objectForKey:@"contact"];
	if ([dict objectForKey:@"customInfo"])
		self.package.customInfoURL = [NSURL URLWithString:[dict objectForKey:@"customInfo"]];
//	if (![self.package.source.isTrusted boolValue])		// disable custom infos for non-trusted sources
//		self.package.customInfoURL = nil;	
	if ([dict objectForKey:@"url"])
		self.package.url = [NSURL URLWithString:[dict objectForKey:@"url"]];
	if ([dict objectForKey:@"icon"])
		self.package.iconURL = [NSURL URLWithString:[dict objectForKey:@"icon"]];
	if ([dict objectForKey:@"dependencies"] && [[dict objectForKey:@"dependencies"] isKindOfClass:[NSArray class]])
		self.package.dependencies = [NSMutableArray arrayWithArray:[dict objectForKey:@"dependencies"]];
		
	[self.package commit];
	
	NSNotification* notification = [NSNotification notificationWithName:ATPackageInfoDoneFetchingNotification object:self.package userInfo:nil];
	
	[[NSNotificationQueue defaultQueue] enqueueNotification:notification postingStyle:NSPostNow];
	
	[[ATPipelineManager sharedManager] taskDoneWithSuccess:self];
}

- (void)download:(ATURLDownload *)dl didFailWithError:(NSError *)error
{
	[[NSNotificationCenter defaultCenter] performSelectorOnMainThread:@selector(postNotification:) withObject:[NSNotification notificationWithName:ATPackageInfoErrorFetchingNotification object:self.package userInfo:nil] waitUntilDone:NO];
	
	[[ATPipelineManager sharedManager] taskDoneWithError:self error:error];
}

@end
