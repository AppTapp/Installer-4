//
//  ATPackageInfoFetch.m
//  Installer
//
//  Created by Slava Karpenko on 7/11/08.
//  Copyright 2008 RiP Dev. All rights reserved.
//

#import "ATPackageIconFetch.h"
#import "ATPackage.h"
#import "ATSource.h"
#import "ATPipelineManager.h"
#import "NSURL+AppTappExtensions.h"
#import "NSString+AppTappExtensions.h"
#import "ATURLDownload.h"

@implementation ATPackageIconFetch

@synthesize package;
@synthesize source;
@synthesize download;
@synthesize tempFileName;

- initWithPackage:(ATPackage*)pack source:(ATSource*)src
{
	if (self = [super init])
	{
		self.package = pack;
		self.source = src;
	}
	
	return self;
}

- (void)dealloc
{
	[self.download cancel];
    if (download.delegate == self)
        download.delegate = nil;

	self.package = nil;
	self.source = nil;
	self.download = nil;
	self.tempFileName = nil;

	[super dealloc];
}

#pragma mark -
#pragma mark ATSource Protocol

- (NSString*)taskID
{
	return [NSString stringWithFormat:@"icon:%@", self.package ? self.package.identifier : [self.source.location absoluteString]];
}

- (NSString*)taskDescription
{
	return [NSString stringWithFormat:NSLocalizedString(@"Fetching icon for %@...", @""), self.package ? self.package.name : self.source.name];
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
	
	// check if we're on wi-fi
	NSURL* sourceURL = nil;
	
	if (self.package)
		sourceURL = [self.package.iconURL URLWithInstallerParameters];
	else
		sourceURL = [self.source.iconURL URLWithInstallerParameters];
		
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
	NSData* iconData = [NSData dataWithContentsOfFile:self.tempFileName];
	
	[[NSFileManager defaultManager] removeItemAtPath:self.tempFileName error:nil];
	
	if (iconData)
	{
#ifdef INSTALLER_APP
        NSBitmapImageRep* finalImage = [NSBitmapImageRep imageRepWithData:iconData];
#else
		UIImage* finalImage = [UIImage imageWithData:iconData];
#endif // INSTALLER_APP
		
		if (finalImage)
		{
			NSString* cachedIconFileName = nil;
			NSString* hash = nil;
			
			if (self.package)
				hash = [[self.package.iconURL absoluteString] MD5Hash];
			else
				hash = [[self.source.iconURL absoluteString] MD5Hash];
			
			if (hash)
			{
				cachedIconFileName = [[__ICON_CACHE_PATH__ stringByAppendingPathComponent:hash] stringByAppendingPathExtension:@"png"];

				[[NSFileManager defaultManager] createPath:__ICON_CACHE_PATH__ handler:nil];
#ifdef INSTALLER_APP
				[[finalImage representationUsingType:NSPNGFileType properties:nil] writeToFile:cachedIconFileName atomically:YES];
#else
				[UIImagePNGRepresentation(finalImage) writeToFile:cachedIconFileName atomically:YES];
#endif // INSTALLER_APP
				
				[[NSNotificationCenter defaultCenter] performSelectorOnMainThread:@selector(postNotification:) withObject:[NSNotification notificationWithName:(self.package!=nil)?ATPackageInfoIconChangedNotification:ATSourceInfoIconChangedNotification object:(self.package?(id)self.package:(id)self.source) userInfo:nil] waitUntilDone:NO];
			}
		}
	}
	
	[[ATPipelineManager sharedManager] taskDoneWithSuccess:self];
}

- (void)download:(ATURLDownload *)dl didFailWithError:(NSError *)error
{
	[[ATPipelineManager sharedManager] taskDoneWithError:self error:error];
}

@end
