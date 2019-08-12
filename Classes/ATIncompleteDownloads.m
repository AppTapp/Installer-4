//
//  ATIncompleteDownloads.m
//  Installer
//
//  Created by Slava Karpenko on 25/08/2008.
//  Copyright 2008 RiP Dev. All rights reserved.
//

#import "ATIncompleteDownloads.h"
#import "ATDatabase.h"
#import "ATResultSet.h"
#import "ATPackageManager.h"
#import "ATIncompleteDownload.h"
#import "NSFileManager+AppTappExtensions.h"

@implementation ATIncompleteDownloads

- (ATIncompleteDownload *)downloadWithLocation:(NSURL*)url
{
	ATResultSet * res = [[ATDatabase sharedDatabase] executeQuery:@"SELECT RowID FROM incomplete_downloads WHERE url = ? LIMIT 1", [url absoluteString]];
	
	if(res && [res next]) {
		ATIncompleteDownload* dl = [[[ATIncompleteDownload alloc] initWithID:[res intForColumn:@"RowID"]] autorelease];
		[res close];
		return dl;
	}
	[res close];
	
	return nil;
}

- (void)cleanupTempFolder
{
	if(![[NSFileManager defaultManager] fileExistsAtPath:__DOWNLOADS_PATH__]) {
		[[NSFileManager defaultManager] createPath:__DOWNLOADS_PATH__ handler:nil];
	}
	
	NSDate* cutoffDate = [NSDate dateWithTimeIntervalSinceNow:-(60.*60.*24.*3.)];
	
	ATResultSet * res = [[ATDatabase sharedDatabase] executeQuery:@"SELECT RowID, path FROM incomplete_downloads WHERE date < ?", cutoffDate];
	
	while (res && [res next]) {
		ATIncompleteDownload* dl = [[[ATIncompleteDownload alloc] initWithID:[res intForColumn:@"RowID"]] autorelease];
		
		if (dl && dl.path)
			[[NSFileManager defaultManager] removeItemAtPath:dl.path error:nil];
		
		[dl remove];
	}
	
	[res close];
}

@end
