//
//  ATSourceRefresh.m
//  Installer
//
//  Created by Slava Karpenko on 7/8/08.
//  Copyright 2008 RiP Dev. All rights reserved.
//

#include <sys/time.h>
#import "ATSourceRefresh.h"
#import "ATSource.h"
#import "ATSources.h"
#import "ATDatabase.h"
#import "ATPackageManager.h"
#import "NSURL+AppTappExtensions.h"
#import "ATPipelineManager.h"
#import "ATURLDownload.h"
#import "ATPackage.h"
#import "ATPipeline.h"
#import "ATCydiaRepositoryParser.h"
#import "EXArray.h"

NSString* const ATSourceRefreshHTTPPrefixString = @"http://";
NSString* const ATCydiaIconPathFormatString = @"http://cache.saurik.com/cydia/icon/%@.png";

/*********        private interface for ATSourceRefresh        *********/

@interface ATSourceRefresh (Private)

- (ATCydiaRepositoryNode*)cydiaRepositoryRootNodeForURL:(NSURL*)sourceURL nodeHTMLFilePath:(NSString*)nodeHTMLPath;

@end

#pragma mark -

@implementation ATSourceRefresh

@synthesize source;
@synthesize download;
@synthesize tempFileName;
@synthesize description;
@synthesize canCancel;

//    #define DEBUG_TIMING_BEGIN() { struct timeval DeT_before, DeT_after; gettimeofday(&DeT_before,NULL);
//    #define DEBUG_TIMING_END(xxxx) gettimeofday(&DeT_after,NULL); timersub(&DeT_after,&DeT_before,&DeT_after); fprintf(stderr, "[i] Timing @ %s: %.03fms\n", xxxx, (double)((DeT_after.tv_sec * 1000000) + DeT_after.tv_usec) / 1000); }
//    #define DEBUG_TIMING_END_NOBRACE(xxxx) gettimeofday(&DeT_after,NULL); timersub(&DeT_after,&DeT_before,&DeT_after); fprintf(stderr, "[i] Timing @ %s: %.03fms\n", xxxx, (double)((DeT_after.tv_sec * 1000000) + DeT_after.tv_usec) / 1000);
//	#define DEBUG_TIMING_RESTART() gettimeofday(&DeT_before,NULL)
	
#define DEBUG_TIMING_BEGIN()
#define DEBUG_TIMING_END(xxxx)
#define DEBUG_TIMING_END_NOBRACE(xxxx)
#define DEBUG_TIMING_RESTART()

+ (ATSourceRefresh*)sourceRefreshWithSourceLocation:(NSString*)location
{
	ATSource* src = [[[ATPackageManager sharedPackageManager] sources] sourceWithLocation:location];
	
	if (src)
		return [[(ATSourceRefresh*)[ATSourceRefresh alloc] initWithSource:src] autorelease];
	
	return nil;
}

+ (ATSourceRefresh*)sourceRefreshWithSource:(ATSource*)src
{
	return [[(ATSourceRefresh*)[ATSourceRefresh alloc] initWithSource:src] autorelease];
}

- (ATSourceRefresh*)initWithSource:(ATSource*)src
{
	if (self = [super init])
	{
		self.source = src;
		self.canCancel = YES;
		self.description = [NSString stringWithFormat:NSLocalizedString(@"Waiting on %@...", @""), self.source.location];
		progress = -1.;
	}
	
	return self;
}

- (void)dealloc
{
	[self.download cancel];
    if (download.delegate == self)
        download.delegate = nil;

	self.source = nil;
	self.download = nil;

    [rootNode release];

	[super dealloc];
}

#pragma mark -
#pragma mark ATTask Protocol

- (NSString*)taskID
{
	return [NSString stringWithFormat:@"refresh.%@", [self.source.location absoluteString]];
}

- (NSString*)taskDescription
{
	return self.description;
}

- (NSString*)taskLocalizedObjectName
{
	return self.source.name;
}

- (double)taskProgress
{
	return progress;
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
	
	NSURL* sourceURL = [self.source.location URLWithInstallerParameters];
	
	self.description = [NSString stringWithFormat:NSLocalizedString(@"Refreshing %@...", @""), self.source.location];
	
	self.download = [[[ATURLDownload alloc] initWithRequest:[NSURLRequest requestWithURL:sourceURL] delegate:self] autorelease];
}

- (BOOL)taskCanCancel
{
	return self.canCancel;
}

- (void)taskCancel
{
	if (!self.canCancel)
		return;
	
	if (!self.download)
		[[ATPipelineManager sharedManager] taskDoneWithSuccess:self];
	
	[self.download cancelDownload];
}


#pragma mark -
#pragma mark NSURLDownload delegate

- (void)download:(ATURLDownload*)dl didCreateDestination:(NSString*)path
{
	self.tempFileName = path;
}

- (void)downloadDidFinish:(ATURLDownload*)dl
{
	self.canCancel = NO;
	
    // do processing
    DEBUG_TIMING_BEGIN();
    self.description = NSLocalizedString(@"Processing index...", @"");
	progress = .0;
    [[ATPipelineManager sharedManager] taskStatusChanged:self];
    DEBUG_TIMING_END("Task status changed");
    
    DEBUG_TIMING_BEGIN();
    
#ifdef INSTALLER_APP_DISABLE_PUSHER
    NSDictionary* dict = nil;
#else
    NSDictionary* dict = [NSDictionary dictionaryWithContentsOfFile:self.tempFileName];
#endif // INSTALLER_APP_DISABLE_PUSHER

    DEBUG_TIMING_END_NOBRACE("Load of dictionary");
    DEBUG_TIMING_RESTART();
    
    if (dict == nil)
    {
         // Try to refresh a Cydia source.
        if (!cydiaSource)
        {
            cydiaSource = YES;

            progress = -1.0;
            [[ATPipelineManager sharedManager] taskStatusChanged:self];

            self.source.hasErrors = [NSNumber numberWithBool:NO];
            [self.source commit];

            [[self cydiaRepositoryRootNodeForURL:self.source.location nodeHTMLFilePath:self.tempFileName] startScan];

            if (self.tempFileName != nil)
                [[NSFileManager defaultManager] removeItemAtPath:self.tempFileName error:nil];

            return;
        }
    }

    if (self.tempFileName != nil)
        [[NSFileManager defaultManager] removeItemAtPath:self.tempFileName error:nil];
    
    if (!dict)
    {
        NSError* err = [NSError errorWithDomain:NSCocoaErrorDomain code:13 userInfo:[NSDictionary dictionaryWithObject:[NSString stringWithFormat:@"Unable to decode source at %@", self.source.location] forKey:NSLocalizedDescriptionKey]];
        
        self.source.hasErrors = [NSNumber numberWithBool:YES];
        [self.source commit];
        
        [[ATPipelineManager sharedManager] taskDoneWithError:self error:err];

        return;
    }
    
    DEBUG_TIMING_RESTART();

    NSDictionary* info = [dict objectForKey:@"info"];
    
    if (info)
    {
        // update the repo info
        if ([info objectForKey:@"name"])
            self.source.name = [info objectForKey:@"name"];
        if ([info objectForKey:@"description"])
            self.source.description = [info objectForKey:@"description"];
        if ([info objectForKey:@"maintainer"])
            self.source.maintainer = [info objectForKey:@"maintainer"];
        if ([info objectForKey:@"url"])
            self.source.url = [NSURL URLWithString:[info objectForKey:@"url"]];
        if ([info objectForKey:@"contact"])
            self.source.contact = [info objectForKey:@"contact"];
        if ([info objectForKey:@"category"])
            self.source.category = [info objectForKey:@"category"];
        if ([info objectForKey:@"icon"])
            self.source.iconURL = [NSURL URLWithString:[info objectForKey:@"icon"]];
    }
    
    self.source.lastrefresh = [NSDate date];
    self.source.hasErrors = [NSNumber numberWithBool:NO];

    [self.source commit];
    DEBUG_TIMING_END_NOBRACE("Source info update");

    // Now let's do the packages :)
    
    NSArray* packages = [dict objectForKey:@"packages"];
    NSMutableArray* pkgsToAdd = [NSMutableArray arrayWithCapacity:0];
    
    //[[ATDatabase sharedDatabase] beginTransaction];

    // Remove all packages for this source - we will re-add them now
    // We should load into a cache table first, then just move data instantly, so the user doesnt have to wait maybe?
    self.description = NSLocalizedString(@"Processing packages...", @"");
    [[ATPipelineManager sharedManager] taskStatusChanged:self];

//	[[ATDatabase sharedDatabase] executeUpdate:[NSString stringWithFormat:@"DELETE FROM packages WHERE source = %u AND isInstalled <> 1", self.source.entryID]];
//	[[ATDatabase sharedDatabase] executeUpdate:[NSString stringWithFormat:@"UPDATE packages SET source = NULL WHERE source = %u AND isInstalled = 1", self.source.entryID]];
    NSString* tempTableName = [NSString stringWithFormat:@"TEMP_srcRefresh_0x%X", self];
    
//	Log(@"Using temporary table %@", tempTableName);
    
    DEBUG_TIMING_RESTART();
    [[ATDatabase sharedDatabase] executeUpdate:[NSString stringWithFormat:@"CREATE TEMP TABLE %@ ( identifier TEXT )", tempTableName]];
    DEBUG_TIMING_END_NOBRACE("Create temp table");
    
    DEBUG_TIMING_RESTART();
	double totPackages = [packages count];
	double procPackages = 0;
	
    for (NSDictionary* package in packages)
    {
		progress = (procPackages++ / totPackages);
		[[ATPipelineManager sharedManager] taskStatusChanged:self];
		
        // Do some sanity checking on the package...
        if (![package objectForKey:@"identifier"] && ![package objectForKey:@"bundleIdentifier"])
        {
            //Log(@"ATSourceRefresh: ignoring package %@ (no identifier field)", package);
            continue;
        }
        
        if (![[package objectForKey:@"version"] versionNumber])
        {
            //Log(@"ATSourceRefresh: ignoring package %@ (no version number or wrong format of version number)", package);
            continue;
        }
        
        NSString* identifier = [package objectForKey:@"identifier"];
        if (!identifier)
            identifier = [package objectForKey:@"bundleIdentifier"];
            
        int rrr = [[ATDatabase sharedDatabase] executeUpdate:[NSString stringWithFormat:@"INSERT INTO %@ VALUES ( ? )", tempTableName], identifier];		
        if (rrr != SQLITE_OK)
            Log(@"INSERT INTO %@ VALUES ( '%@' ) failed with %d", tempTableName, identifier, rrr);

        //Log(@"package = %@", package);
        
        unsigned long long localPackageVersion = 0;
        NSDictionary* pp = nil;
        ATPackage* p = [[ATPackageManager sharedPackageManager].packages packageWithIdentifier:identifier];
        
        if (!p)		// Package not found, so just blindly add it to the array of packages to add
        {
            // but first check if it was already queued for addition from the same repo
            BOOL f = NO;
            
            for (NSDictionary* pee in pkgsToAdd)
            {
                NSString* id1 = [pee objectForKey:@"identifier"];
                if (!id1)
                    id1 = [pee objectForKey:@"bundleIdentifier"];
                
                if ([id1 isEqualToString:identifier])
                {
                    f = YES;
                    localPackageVersion = [[pee objectForKey:@"version"] versionNumber];
                    pp = pee;
                }
            }
            
            if (!f)
            {
                //Log(@"Package %@ was not found, blindly adding it...", identifier);
                [pkgsToAdd addObject:package];
                continue;
            }
        }
        
        if (p)
            localPackageVersion = [p.version versionNumber];		// in this case, the newest available package in the db
        unsigned long long remotePackageVersion = [[package objectForKey:@"version"] versionNumber];

        // Version is the same, so we'll just skip
        if (localPackageVersion == remotePackageVersion)
        {
#ifdef INSTALLER_APP
            if (p != nil && (p.source.entryID == self.source.entryID || (p.source.location == nil && !p.isCydiaPackage)))
            {
                //Log(@"Package %@ is the same version as found. Skipping (but refreshing the info).", identifier);

                p.moreURL = [package objectForKey:@"url"];
                if ([package objectForKey:@"icon"])
                    p.iconURL = [NSURL URLWithString:[package objectForKey:@"icon"]];
                p.description = [package objectForKey:@"description"];
                p.category = [package objectForKey:@"category"];
                p.version = [package objectForKey:@"version"];
                p.date = [NSDate dateWithTimeIntervalSince1970:[[package objectForKey:@"date"] doubleValue]];
                p.name = [package objectForKey:@"name"];
                p.source = self.source;

                [p commit];
            }
#else
            if (p != nil && p.source.entryID == self.source.entryID)
            {
                //Log(@"Package %@ is the same version as found. Skipping (but refreshing the info).", identifier);

                p.moreURL = [package objectForKey:@"url"];
                if ([package objectForKey:@"icon"])
                    p.iconURL = [NSURL URLWithString:[package objectForKey:@"icon"]];
                p.description = [package objectForKey:@"description"];
                p.category = [package objectForKey:@"category"];
                p.version = [package objectForKey:@"version"];
                p.date = [NSDate dateWithTimeIntervalSince1970:[[package objectForKey:@"date"] doubleValue]];
                p.name = [package objectForKey:@"name"];
                p.source = self.source;

                [p commit];
            }
#endif // INSTALLER_APP
            
            continue;
        }
        
        // What we have in the database is newer than the package offered. So we'll skip it too
        if (localPackageVersion > remotePackageVersion)
        {
            //Log(@"Package %@ is older version as found. Skipping.", identifier);
            continue;
        }
        
        // Up to this point, we have a version that's newer than the one we have.
        /*NSArray* allpks = [[ATPackageManager sharedPackageManager].packages packagesWithIdentifier:identifier];
        for (ATPackage* ppp in allpks)
        {
            if (ppp.isInstalled)
                continue;
            
            
        }*/
        
        //Log(@"Queuing package %@ for addition (newer version than we have)...", identifier);
        
        if (pp)
            [pkgsToAdd removeObject:pp];
        
        [pkgsToAdd addObject:package];
        
        // drop older version from the database if it's not installed.
        [[ATDatabase sharedDatabase] executeUpdate:@"DELETE FROM packages WHERE identifier = ? AND isInstalled <> 1", identifier, nil];
    }
    
    DEBUG_TIMING_END_NOBRACE("Processing packages");
    DEBUG_TIMING_RESTART();
    
    for (NSDictionary* package in pkgsToAdd)
    {
        ATPackage* p = [ATPackage packageWithID:0];
        
        if ([package objectForKey:@"identifier"])
            p.identifier = [package objectForKey:@"identifier"];
        else
            p.identifier = [package objectForKey:@"bundleIdentifier"];
            
        p.category = [package objectForKey:@"category"];
        p.version = [package objectForKey:@"version"];
        p.date = [NSDate dateWithTimeIntervalSince1970:[[package objectForKey:@"date"] doubleValue]];
        p.name = [package objectForKey:@"name"];
        p.moreURL = [package objectForKey:@"url"];
        if ([package objectForKey:@"icon"])
            p.iconURL = [NSURL URLWithString:[package objectForKey:@"icon"]];
        p.description = [package objectForKey:@"description"];
        
        p.source = self.source;
        
        [p commit];
    }
    DEBUG_TIMING_END_NOBRACE("Adding packages");
    DEBUG_TIMING_RESTART();
    
    // Now remove all packages that did not get to the sources list
    [[ATDatabase sharedDatabase] executeUpdate:[NSString stringWithFormat:@"DELETE FROM packages WHERE identifier NOT IN ( SELECT identifier FROM %@ ) AND source = %u AND isInstalled <> 1", tempTableName, self.source.entryID]];		
//	Log(@"ATSourceRefresh: Removed %d outdated packages for %@", [[ATDatabase sharedDatabase] affectedRows], self.source);
    [[ATDatabase sharedDatabase] executeUpdate:[NSString stringWithFormat:@"DROP TABLE %@", tempTableName]];
    DEBUG_TIMING_END_NOBRACE("Dropping packages using temp table");
    DEBUG_TIMING_RESTART();
    
    //[[ATDatabase sharedDatabase] commit];
    
    // See if we want to post a notification
    BOOL hasOtherRefreshes = NO;
    ATPipeline* pipe = [[ATPipelineManager sharedManager] findPipelineForTask:self];
    if ([pipe existTaskWithPrefix:@"refresh." ignoreTask:self])
        hasOtherRefreshes = YES;

    if (!hasOtherRefreshes)
        [[NSNotificationCenter defaultCenter] performSelectorOnMainThread:@selector(postNotification:) withObject:[NSNotification notificationWithName:ATSourceUpdatedNotification object:self.source userInfo:nil] waitUntilDone:NO];
    
    [[ATPipelineManager sharedManager] taskDoneWithSuccess:self];
    DEBUG_TIMING_END("Source refresh all");
}

- (void)download:(ATURLDownload *)dl didFailWithError:(NSError *)error
{
	//Log(@"ATSourceRefresh: download did fail (%@) = %@!", self.tempFileName, error);

	self.source.hasErrors = [NSNumber numberWithBool:YES];
	self.source.lastrefresh = [NSDate date];
	[self.source commit];

    // See if we want to post a notification
    BOOL hasOtherRefreshes = NO;
    ATPipeline* pipe = [[ATPipelineManager sharedManager] findPipelineForTask:self];
    if ([pipe existTaskWithPrefix:@"refresh." ignoreTask:self])
        hasOtherRefreshes = YES;

    if (!hasOtherRefreshes)
        [[NSNotificationCenter defaultCenter] performSelectorOnMainThread:@selector(postNotification:) withObject:[NSNotification notificationWithName:ATSourceUpdatedNotification object:self.source userInfo:nil] waitUntilDone:NO];

	[[ATPipelineManager sharedManager] taskDoneWithError:self error:error];
}

#pragma mark -

- (ATCydiaRepositoryNode*)cydiaRepositoryRootNodeForURL:(NSURL*)sourceURL nodeHTMLFilePath:(NSString*)nodeHTMLPath
{
    if (rootNode == nil)
    {
        rootNode = [[ATCydiaRepositoryNode allocWithZone:[self zone]] initWithURL:sourceURL nodeHTMLFilePath:nodeHTMLPath];
        rootNode._delegate = self;
    }

    return rootNode;
}

- (void)scanDidFinishInNode:(ATCydiaRepositoryNode*)node
{
    DEBUG_TIMING_RESTART();

    NSString* packagesFileTempPath = [rootNode packagesFileTempPath];
    if (packagesFileTempPath != nil)
    {
        NSString* releaseFileTempPath = [rootNode releaseFileTempPath];
        ATCydiaRepositoryParser* releaseParser = [ATCydiaRepositoryParser parserWithContentOfFile:releaseFileTempPath];

        NSDictionary* info = [[releaseParser dictionaryRepresentation] extraFirstObject];

        // Remove temp release file.
        if (releaseFileTempPath != nil)
            [[NSFileManager defaultManager] removeItemAtPath:releaseFileTempPath error:nil];

        if (info != nil)
        {
            Log(@"%@", info);

            // Update the repo info.
            id value = [info objectForKey:@"origin"];
            if (value == nil)
                value = [info objectForKey:@"label"];
            if (value != nil)
                self.source.name = value;

            value = [info objectForKey:@"description"];
            if (value != nil)
                self.source.description = value;

            value = [info objectForKey:@"origin"];
            if (value != nil)
                self.source.maintainer = value;

            value = [info objectForKey:@"suit"];
            if (value != nil)
                self.source.category = value;
        }
        else
        {
            NSString* sourceName = [rootNode._url host];
            if (sourceName == nil)
            {
                NSArray* pathComponents = [[rootNode._url absoluteString] pathComponents];
                sourceName = [pathComponents extraObjectAtIndex:1];

                if (sourceName == nil)
                    sourceName = [pathComponents lastObject];

                if (sourceName == nil)
                    sourceName = @"";
            }

            self.source.name = sourceName;
            self.source.description = self.source.name;
        }

        self.source.hasErrors = [NSNumber numberWithBool:NO];
        self.source.lastrefresh = [NSDate date];
#ifdef INSTALLER_APP
        self.source.isCydiaSource = [NSNumber numberWithBool:YES];
#endif // INSTALLER_APP

        self.source.location = node._url;
        self.source.url = self.source.location;

        [self.source commit];
    }
    else
    {
        self.source.hasErrors = [NSNumber numberWithBool:YES];
        self.source.lastrefresh = [NSDate date];

        [self.source commit];
    }

    DEBUG_TIMING_END_NOBRACE("Source info update");

    ATCydiaRepositoryParser* packagesParser = [ATCydiaRepositoryParser parserWithContentOfFile:packagesFileTempPath];
    NSArray* packages = [packagesParser dictionaryRepresentation];

    // Remove temp packages file.
    if (packagesFileTempPath != nil)
        [[NSFileManager defaultManager] removeItemAtPath:packagesFileTempPath error:nil];

    if (packages != nil)
    {
        // Now let's do the packages :)
        NSMutableArray* pkgsToAdd = [NSMutableArray arrayWithCapacity:0];

        // Remove all packages for this source - we will re-add them now
        // We should load into a cache table first, then just move data instantly, so the user doesnt have to wait maybe?
        self.description = NSLocalizedString(@"Processing packages...", @"");
        [[ATPipelineManager sharedManager] taskStatusChanged:self];

        NSString* tempTableName = [NSString stringWithFormat:@"TEMP_srcRefresh_0x%X", self];

        DEBUG_TIMING_RESTART();
        [[ATDatabase sharedDatabase] executeUpdate:[NSString stringWithFormat:@"CREATE TEMP TABLE %@ ( identifier TEXT )", tempTableName]];
        DEBUG_TIMING_END_NOBRACE("Create temp table");

        DEBUG_TIMING_RESTART();
        for (NSDictionary* package in packages)
        {
            // Check for Cydia repositories.
            if ([[[package objectForKey:@"section"] lowercaseString] isEqualToString:@"repositories"])
                continue;

            // Check for cydia::commercial.
            NSString* tagString = [[package objectForKey:@"tag"] lowercaseString];
            if (tagString != nil && [tagString rangeOfString:@"cydia::commercial"].location != NSNotFound)
                continue;

            // Do some sanity checking on the package...
            if ([package objectForKey:@"package"] == nil && [package objectForKey:@"filename"] == nil && [package objectForKey:@"bundle"] == nil)
                continue;

            NSString* identifier = [package objectForKey:@"package"];
            if (identifier == nil)
                identifier = [package objectForKey:@"bundle"];

            identifier = [identifier lowercaseString];

            int rrr = [[ATDatabase sharedDatabase] executeUpdate:[NSString stringWithFormat:@"INSERT INTO %@ VALUES ( ? )", tempTableName], identifier];		
            if (rrr != SQLITE_OK)
                Log(@"INSERT INTO %@ VALUES ( '%@' ) failed with %d", tempTableName, identifier, rrr);

            unsigned long long localPackageVersion = 0;
            NSDictionary* pp = nil;
            ATPackage* p = [[ATPackageManager sharedPackageManager].packages packageWithIdentifier:identifier];

            if (!p) // Package not found, so just blindly add it to the array of packages to add.
            {
                // But first check if it was already queued for addition from the same repo.
                BOOL f = NO;

                for (NSDictionary* pee in pkgsToAdd)
                {
                    NSString* id1 = [pee objectForKey:@"package"];
                    if (id1 == nil)
                        id1 = [pee objectForKey:@"bundle"];

                    id1 = [id1 lowercaseString];

                    if ([id1 isEqualToString:identifier])
                    {
                        f = YES;
                        localPackageVersion = [[pee objectForKey:@"version"] versionNumber];
                        pp = pee;
                    }
                }

                if (!f)
                {
                    [pkgsToAdd addObject:package];
                    continue;
                }
            }
        
            if (p)
                localPackageVersion = [p.version versionNumber]; // In this case, the newest available package in the db.

            unsigned long long remotePackageVersion = [[package objectForKey:@"version"] versionNumber];

            // Version is the same, so we'll just skip.
            if (localPackageVersion == remotePackageVersion)
            {
#ifdef INSTALLER_APP
                if (p != nil && (p.source.entryID == self.source.entryID || (p.source.location == nil && p.isCydiaPackage)))
                {
                    id value = [package objectForKey:@"icon"];
                    if (value == nil || [(NSString*)value hasPrefix:@"file:"])
                        value = [NSString stringWithFormat:ATCydiaIconPathFormatString, p.identifier];

                    p.iconURL = [NSURL URLWithString:value];

                    value = [package objectForKey:@"filename"];
                    if (value != nil)
                    {
                        if ([value hasPrefix:@"/"])
                            value = [value substringFromIndex:1];

                        p.location = [NSURL URLWithString:[[rootNode._url absoluteString] stringByAppendingString:[value stringByStandardizingPath]]];
                    }

                    value = [package objectForKey:@"maintainer"];
                    if (value != nil)
                        p.maintainer = value;

                    value = [package objectForKey:@"sponsor"];
                    if (value != nil)
                        p.sponsor = value;

                    value = [package objectForKey:@"description"];
                    if (value != nil)
                        p.description = value;

                    value = [package objectForKey:@"section"];
                    if (value != nil)
                    {
                        // Normalize the category string.
                        value = [value stringByReplacingOccurrencesOfString:@"\x0A" withString:@""];
                        value = [value stringByReplacingOccurrencesOfString:@"\x0D" withString:@""];

                        p.category = value;
                    }

                    value = [package objectForKey:@"version"];
                    if (value != nil)
                        p.version = value;

                    p.dependencies = [ATCydiaRepositoryParser dependsFromDictionary:package];
                    p.conflicts = [ATCydiaRepositoryParser conflictsFromDictionary:package];

                    NSInteger size = [[package objectForKey:@"size"] intValue];
                    if (size > 0)
                        p.size = [NSNumber numberWithInteger:size];

                    value = [package objectForKey:@"name"];
                    if (value == nil)
                        value = [package objectForKey:@"package"];

                    if (value != nil)
                        p.name = value;

                    value = [package objectForKey:@"depiction"];
                    if (value == nil)
                    {
                        value = [package objectForKey:@"homepage"];
                        if (value == nil)
                            value = [package objectForKey:@"website"];
                    }        

                    if (value != nil)
                        p.url = value;

                    value = [package objectForKey:@"essential"];
                    if (value != nil && [value isKindOfClass:[NSString class]])
                        p.isEssential = [(NSString*)value boolValue];

                    p.source = self.source;
                    p.isCydiaPackage = YES;

                    [p commit];
                }
#else
                if (p != nil && (p.source.entryID == self.source.entryID || (p.source == nil && p.synchronizeStatus > 0 && p.synchronizeCydiaPackage)))
                {
                    id value = [package objectForKey:@"icon"];
                    if (value == nil || [(NSString*)value hasPrefix:@"file:"])
                        value = [NSString stringWithFormat:ATCydiaIconPathFormatString, p.identifier];

                    p.iconURL = [NSURL URLWithString:value];

                    value = [package objectForKey:@"filename"];
                    if (value != nil)
                    {
                        if ([value hasPrefix:@"/"])
                            value = [value substringFromIndex:1];

                        p.location = [NSURL URLWithString:[[rootNode._url absoluteString] stringByAppendingString:[value stringByStandardizingPath]]];
                    }

                    value = [package objectForKey:@"maintainer"];
                    if (value != nil)
                        p.maintainer = value;

                    value = [package objectForKey:@"sponsor"];
                    if (value != nil)
                        p.sponsor = value;

                    value = [package objectForKey:@"description"];
                    if (value != nil)
                        p.description = value;

                    value = [package objectForKey:@"section"];
                    if (value != nil)
                    {
                        // Normalize the category string.
                        value = [value stringByReplacingOccurrencesOfString:@"\x0A" withString:@""];
                        value = [value stringByReplacingOccurrencesOfString:@"\x0D" withString:@""];

                        p.category = value;
                    }

                    value = [package objectForKey:@"version"];
                    if (value != nil)
                        p.version = value;

                    p.dependencies = [ATCydiaRepositoryParser dependsFromDictionary:package];

                    NSInteger size = [[package objectForKey:@"size"] intValue];
                    if (size > 0)
                        p.size = [NSNumber numberWithInteger:size];

                    value = [package objectForKey:@"name"];
                    if (value == nil)
                        value = [package objectForKey:@"package"];

                    if (value != nil)
                        p.name = value;

                    value = [package objectForKey:@"depiction"];
                    if (value == nil)
                    {
                        value = [package objectForKey:@"homepage"];
                        if (value == nil)
                            value = [package objectForKey:@"website"];
                    }        

                    if (value != nil)
                        p.url = value;

                    p.source = self.source;

                    [p commit];
                }
#endif // INSTALLER_APP

                continue;
            }

            // What we have in the database is newer than the package offered. So we'll skip it too
            if (localPackageVersion > remotePackageVersion)
                continue;

            if (pp)
                [pkgsToAdd removeObject:pp];

            package = [[package mutableCopy] autorelease];
            [(NSMutableDictionary*)package setObject:[NSDate date] forKey:@"date"];

            [pkgsToAdd addObject:package];

            // Drop older version from the database if it's not installed.
            [[ATDatabase sharedDatabase] executeUpdate:@"DELETE FROM packages WHERE identifier = ? AND isInstalled <> 1", identifier, nil];
        }

        DEBUG_TIMING_END_NOBRACE("Processing packages");
        DEBUG_TIMING_RESTART();

        for (NSDictionary* package in pkgsToAdd)
        {
            ATPackage* p = [ATPackage packageWithID:0];

            id value = [package objectForKey:@"package"];
            if (value == nil)
                value = [package objectForKey:@"bundle"]; 

            value = [value lowercaseString];

            if (value != nil)
                p.identifier = value;

            value = [package objectForKey:@"maintainer"];
            if (value != nil)
                p.maintainer = value;

            value = [package objectForKey:@"sponsor"];
            if (value != nil)
                p.sponsor = value;

            value = [package objectForKey:@"description"];
            if (value != nil)
                p.description = value;

            value = [package objectForKey:@"section"];
            if (value != nil)
            {
                // Normalize the category string.
                value = [value stringByReplacingOccurrencesOfString:@"\x0A" withString:@""];
                value = [value stringByReplacingOccurrencesOfString:@"\x0D" withString:@""];

                p.category = value;
            }

            value = [package objectForKey:@"version"];
            if (value != nil)
                p.version = value;

            p.dependencies = [ATCydiaRepositoryParser dependsFromDictionary:package];
            p.conflicts = [ATCydiaRepositoryParser conflictsFromDictionary:package];

            NSInteger size = [[package objectForKey:@"size"] intValue];
            if (size > 0)
                p.size = [NSNumber numberWithInteger:size];

            value = [package objectForKey:@"name"];
            if (value == nil)
                value = [package objectForKey:@"package"];

            if (value != nil)
                p.name = value;

            value = [package objectForKey:@"depiction"];
            if (value == nil)
            {
                value = [package objectForKey:@"homepage"];
                if (value == nil)
                    value = [package objectForKey:@"website"];
            }        

            if (value != nil)
                p.url = value;

            value = [package objectForKey:@"filename"];
            if (value != nil)
            {
                if ([value hasPrefix:@"/"])
                    value = [value substringFromIndex:1];

                p.location = [NSURL URLWithString:[[rootNode._url absoluteString] stringByAppendingString:[value stringByStandardizingPath]]];
            }

            value = [package objectForKey:@"icon"];
            if (value == nil || [(NSString*)value hasPrefix:@"file:"])
                value = [NSString stringWithFormat:ATCydiaIconPathFormatString, p.identifier];

            if (value != nil)
                p.iconURL = [NSURL URLWithString:value];

#ifdef INSTALLER_APP
            value = [package objectForKey:@"essential"];
            if (value != nil && [value isKindOfClass:[NSString class]])
                p.isEssential = [(NSString*)value boolValue];

            p.isCydiaPackage = YES;
#endif // INSTALLER_APP

            value = [package objectForKey:@"date"];
            if (value != nil)
                p.date = value;

            p.source = self.source;

            [p commit];
        }

        DEBUG_TIMING_END_NOBRACE("Adding packages");
        DEBUG_TIMING_RESTART();

        // Now remove all packages that did not get to the sources list
        [[ATDatabase sharedDatabase] executeUpdate:[NSString stringWithFormat:@"DELETE FROM packages WHERE identifier NOT IN ( SELECT identifier FROM %@ ) AND source = %u AND isInstalled <> 1", tempTableName, self.source.entryID]];		
        [[ATDatabase sharedDatabase] executeUpdate:[NSString stringWithFormat:@"DROP TABLE %@", tempTableName]];

        DEBUG_TIMING_END_NOBRACE("Dropping packages using temp table");
    }

    DEBUG_TIMING_RESTART();

    // See if we want to post a notification.
    BOOL hasOtherRefreshes = NO;
    ATPipeline* pipe = [[ATPipelineManager sharedManager] findPipelineForTask:self];
    if ([pipe existTaskWithPrefix:@"refresh." ignoreTask:self])
        hasOtherRefreshes = YES;

    if (!hasOtherRefreshes)
        [[NSNotificationCenter defaultCenter] performSelectorOnMainThread:@selector(postNotification:) withObject:[NSNotification notificationWithName:ATSourceUpdatedNotification object:self.source userInfo:nil] waitUntilDone:NO];

    [[ATPipelineManager sharedManager] taskDoneWithSuccess:self];

    DEBUG_TIMING_END("Source refresh all");
}

@end
