#import "ATSearchTask.h"
#import "ATPackage.h"
#import "ATPipelineManager.h"
#import "NSURL+AppTappExtensions.h"
#import "ATURLDownload.h"
#import "ATDatabase.h"
#import "ATSearch.h"

#ifndef INSTALLER_APP
    #import "ATInstaller.h"
#endif // INSTALLER_APP

@implementation ATSearchTask

@synthesize search;
@synthesize download;
@synthesize tempFileName;

- initWithSearch:(ATSearch*)srch
{
	if (self = [super init])
	{
		self.search = srch.searchCriteria;
	}
	
	return self;
}

- (void)dealloc
{
	[self.download cancel];
    if (download.delegate == self)
        download.delegate = nil;

	self.search = nil;
	self.download = nil;
	self.tempFileName = nil;

	[super dealloc];
}

#pragma mark -
#pragma mark ATSource Protocol

- (void)taskCancel
{
	[self.download cancel];
    if (download.delegate == self)
        download.delegate = nil;

	self.download = nil;	
}

- (NSString*)taskID
{
	return @":search";
}

- (NSString*)taskDescription
{
	return [NSString stringWithFormat:NSLocalizedString(@"Searching for \"%@\"...", @""), self.search];
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
	
	NSURL* sourceURL = [NSURL URLWithString:[NSString stringWithFormat:@"http://search.i.ripdev.com/s/?q=%@&os=%@", [self.search stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding], [[ATPlatform firmwareVersion] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding] ]];
	
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
		[[ATPipelineManager sharedManager] taskDoneWithSuccess:self];
		return;
	}
	
	NSArray* res = [dict objectForKey:@"results"];
	if (res)
	{
        ATDatabase* database = [ATDatabase sharedDatabase];

#ifdef INSTALLER_APP
        [database executeUpdate:@"DELETE FROM external_search;"];
#endif // INSTALLER_APP

		for (NSDictionary* p in res)
		{
			if ([[ATPackageManager sharedPackageManager].sources sourceWithLocation:[p objectForKey:@"s"]])
				continue;
			
			// Add it to the search results
#ifdef INSTALLER_APP
			NSString* q = @"INSERT INTO external_search (packageID, sourceName, sourceURL, identifier, name, customInfo, description, version, icon, date) VALUES(NULL, ?, ?, ?, ?, ?, ?, ?, ?, ?);";
#else
			NSString* q = @"INSERT INTO search (packageID, sourceName, sourceURL, identifier, name, customInfo, description, version, icon, date) VALUES(NULL, ?, ?, ?, ?, ?, ?, ?, ?, ?);";
#endif // INSTALLER_APP

			[database executeUpdate:q, [p objectForKey:@"S"],
                                [p objectForKey:@"s"],
                                [p objectForKey:@"I"],
                                [p objectForKey:@"n"],
                                [p objectForKey:@"c"],
                                [p objectForKey:@"D"],
                                [p objectForKey:@"v"],
                                [p objectForKey:@"i"],
                                [NSDate dateWithTimeIntervalSince1970:[[p objectForKey:@"d"] doubleValue]]];
		}
	}
	
	[[NSNotificationCenter defaultCenter] performSelectorOnMainThread:@selector(postNotification:) withObject:[NSNotification notificationWithName:ATSearchResultsUpdatedNotification object:nil userInfo:nil] waitUntilDone:NO];
	
	[[ATPipelineManager sharedManager] taskDoneWithSuccess:self];
}

- (void)download:(ATURLDownload *)dl didFailWithError:(NSError *)error
{
	[[ATPipelineManager sharedManager] taskDoneWithSuccess:self];
}

@end
