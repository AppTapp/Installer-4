//
//  ATPackage.m
//  Installer
//
//  Created by Maksim Rogov on 23/06/08.
//  Copyright 2008 Nullriver, Inc.. All rights reserved.
//

/*********        includes        *********/

#import "ATPackage.h"
#import "ATPipelineManager.h"
#import "ATPackageManager.h"
#import "ATPackageInfoFetch.h"
#import "ATPackages.h"
#import "ATPackageInstallTask.h"
#import "ATPackageUninstallTask.h"
#import "ATPackageIconFetch.h"
#import "ATDatabase.h"
#import "Reachability.h"
#import "NSString+AppTappExtensions.h"
#import "ATQueueFutureInstall.h"
#import "ATPackageUSBInstallTask.h"
#import "ATPackageUSBUninstallTask.h"
#import "ATPackageQueueInstall.h"

#ifdef INSTALLER_APP
    #import "IASynchronizePhoneManager.h"
#endif // INSTALLER_APP

/*********        forward declarations, globals and typedefs        *********/

NSString* ATPackageInfoFetchingNotification = @"com.ripdev.install.package.more-info-fetch.start";
NSString* ATPackageInfoDoneFetchingNotification = @"com.ripdev.install.package.more-info-fetch.done";
NSString* ATPackageInfoErrorFetchingNotification = @"com.ripdev.install.package.more-info-fetch.failed";
NSString* ATPackageInfoIconChangedNotification = @"com.ripdev.install.package.more-info.icon-changed";
NSString* ATPackageInfoRatingChangedNotification = @"com.ripdev.install.package.more-info.rating-changed";

static NSMutableArray* sSharedInstallIdentifiers = nil;

/*********        private interface for ATPackage        *********/

@interface ATPackage (Private)

+ (NSMutableArray*)sharedInstallIdentifiers;
- (BOOL)installUSB:(NSError**)outError inInstall:(BOOL*)outFlag;

@end

#pragma mark -

/*********        implementation for ATPackage        *********/

@implementation ATPackage

@synthesize isSynthetic;
@synthesize syntheticSourceName;
@synthesize syntheticSourceURL;
@synthesize synchronizeStatus;
@synthesize synchronizeVersion;

+ (id)packageWithID:(sqlite_int64)uid
{
	return [[[ATPackage alloc] initWithID:uid] autorelease];
}

- (id)init
{
	if (self = [super initWithTable:@"packages" entryID:0])
	{
		self.isSynthetic = NO;
	}
	
	return self;
}

- (id)initWithID:(sqlite_int64)uid
{
	if (self = [super initWithTable:@"packages" entryID:uid])
	{
		self.isSynthetic = NO;
	}
	
	return self;
}

- (void)dealloc
{
    [synchronizeVersion release];
    [syntheticSourceName release];
    [syntheticSourceURL release];

	[super dealloc];
}

- (ATSource*)source
{
	return self.source;
}

- (NSString*)description
{
	return [NSString stringWithFormat:@"<ATPackage: 0x%X %@>", self, self.identifier];
}

- (void)setIsInstalled:(BOOL)isInstalled
{
	[self performSelector:@selector(_set_isInstalled:) withObject:[NSNumber numberWithBool:isInstalled]];
}

- (BOOL)isInstalled
{
	return [[ATPackageManager sharedPackageManager].packages packageIsInstalled:self.identifier];
}

- (BOOL)hasUpdateAvailable
{
	NSString* q = @"SELECT COUNT(RowID) AS cnt FROM packages WHERE identifier = ? AND isInstalled <> 1";
	ATResultSet* res = [[ATDatabase sharedDatabase] executeQuery:q, self.identifier];
	
	if (res && [res next])
	{
		int count = [res intForColumn:@"cnt"];
		
		[res close];
		return (count > 0);
	}
	
	[res close];
	
	return NO;
}

- (ATPackage*)packageUpdate
{
	NSString* q = @"SELECT RowID AS id FROM packages WHERE identifier = ? AND isInstalled <> 1";
	ATResultSet* res = [[ATDatabase sharedDatabase] executeQuery:q, self.identifier];
	ATPackage* pack = nil;
	
	while (res && [res next])
	{
		ATPackage* p = [ATPackage packageWithID:[res intForColumn:@"id"]];
		
		if ([p.version versionNumber] > [pack.version versionNumber])
			pack = p;
	}
	
	[res close];
	
	return pack;
	
}

- (void)setSource:(ATSource*)source
{
	[self performSelector:@selector(_set_source:) withObject:[NSNumber numberWithUnsignedInt:source.entryID]];
}

- (ATSource*)getSource
{
	// get source id
	NSNumber* sourceID = [self performSelector:@selector(_get_int_source)];
	
	return [[[ATSource alloc] initWithID:[sourceID unsignedIntValue]] autorelease];
}

- (BOOL)isValidPackage {
	if(
	   self.name != nil &&
	   self.version != nil &&
	   self.identifier != nil &&
	   self.location != nil &&
	   self.size != nil
	) return YES;
	else return NO;
}

- (BOOL)isTrustedPackage {
	return [self source].isTrustedSource;
}

- (BOOL)isNewPackage {
	return [self.date timeIntervalSince1970] > [[NSDate dateWithTimeIntervalSinceNow:-60*60*72] timeIntervalSince1970];
}

- (int)caseInsensitiveComparePackageName:(ATPackage *)comparePackage {
	return [self.name caseInsensitiveCompare:comparePackage.name];
}

- (int)caseInsensitiveComparePackageCategory:(ATPackage *)comparePackage {
	NSString * a = [NSString stringWithFormat:@"%@.%@", self.category, self.name];
	NSString * b = [NSString stringWithFormat:@"%@.%@", comparePackage.category, comparePackage.name];
	
	return [a caseInsensitiveCompare:b];
}

- (int)comparePackageDate:(ATPackage *)comparePackage {
	return [comparePackage.date compare:self.date];
}

- (void)setCategory:(NSString*)cat
{
	NSString* newCat = [[NSBundle bundleForClass:[self class]] localizedStringForKey:cat value:cat table:@"CategoryMapping"];
		
	[self performSelector:@selector(_set_category:) withObject:newCat];
}

#pragma mark -
#pragma mark fetchExtendedInfo

- (BOOL)needExtendedInfoFetch
{
	return (self.location == nil || ![[self.location description] length]);
}

- (void)fetchExtendedInfo
{
	if (self.location != nil)		// we have already fetched it
	{
		return;
	}
	
	// Check whether this task is already queued. We specifically check if it's in the misc pipeline, as it also can be in the install pipeline, which means installation task.
	NSString* pipe = nil;
	id existingRefreshTask = [[ATPipelineManager sharedManager] findTaskForID:self.identifier outPipeline:&pipe];
	
	if (existingRefreshTask && [pipe isEqualToString:ATPipelineMisc])
	{
		return;
	}
	
	// otherwise, let's queue the extended info refresh
	ATPackageInfoFetch* apif = [[[ATPackageInfoFetch alloc] initWithPackage:self] autorelease];
	
	[[ATPipelineManager sharedManager] queueTask:apif forPipeline:ATPipelineMisc];
}

#pragma mark -
#pragma mark Installing packages

- (BOOL)install:(NSError**)outError
{
	if (self.isSynthetic)
	{
		[[ATPackageManager sharedPackageManager].sources addSourceWithLocation:self.syntheticSourceURL];
		
		// Queue up the installation task to the same pipeline
		ATQueueFutureInstall* aqfi = [[ATQueueFutureInstall alloc] initWithPackageID:self.identifier];
		
		[[ATPipelineManager sharedManager] queueTask:aqfi forPipeline:ATPipelineSourceRefresh];
		
		[aqfi release];
		
		return YES;
	}
	
	NSString* pipe = nil;
	id existingRefreshTask = [[ATPipelineManager sharedManager] findTaskForID:self.identifier outPipeline:&pipe];
	
	if (existingRefreshTask && [pipe isEqualToString:ATPipelinePackageOperation])
	{
		Log(@"ATPackage: Package: %@: install/update is aready in the pipeline.", self.identifier);
		return YES;
	}
	
	ATPackageQueueInstall* pqi = [[ATPackageQueueInstall alloc] initWithPackage:self];
	[[ATPipelineManager sharedManager] queueTask:pqi forPipeline:ATPipelinePackageOperation];
	[pqi release];
	
	return YES;
}

- (BOOL)_install:(NSError**)outError
{
	if ([self.dependencies count])
	{
		// queue up dependencies if they are not already installed
		for (NSString* depID in self.dependencies)
		{
			ATPackage* dependency = [[ATPackageManager sharedPackageManager].packages packageWithIdentifier:depID];
			if ([[ATPackageManager sharedPackageManager].packages packageIsInstalled:depID])
			{
				if (dependency.hasUpdateAvailable)
				{
					// find the update
					ATPackage* update = dependency.packageUpdate;
					
					if (update)
					{
						if ([update needExtendedInfoFetch])
						{
							ATPackageInfoFetch* pif = [[[ATPackageInfoFetch alloc] initWithPackage:update] autorelease];
							
							[[ATPipelineManager sharedManager] queueTask:pif forPipeline:ATPipelinePackageOperation];
						}
						
						if (![update install:outError])
							return NO;
					}
					else
						continue;
				}
				else
				{
					Log(@"Dependency %@ is already installed, skipping.", depID);
				
					continue;
				}
			}
			
			// Otherwise, let's try to find the dependency in available packages
			ATPackage* dep = [[ATPackageManager sharedPackageManager].packages packageWithIdentifier:depID];
			if (!dep)	// Required dependency not found, bail.
			{
				if (outError)
				{
					NSDictionary* errorDict = [NSDictionary dictionaryWithObjectsAndKeys:	depID, @"packageID",
																							nil];
					NSError* err = [NSError errorWithDomain:AppTappErrorDomain code:kATErrorDependencyNotFound userInfo:errorDict];
					
					*outError = err;
				}
				
				return NO;
			}
			
			// If the dependency has no extended info fetched, queue it up first
			if ([dep needExtendedInfoFetch])
			{
				ATPackageInfoFetch* pif = [[[ATPackageInfoFetch alloc] initWithPackage:dep] autorelease];
			
				[[ATPipelineManager sharedManager] queueTask:pif forPipeline:ATPipelinePackageOperation];
			}
			
			// We found the dependency, queue it up. If it fails, we will silently bail, too.
			if (![dep install:outError])
				return NO;
				
			// Otherwise, all is fine, proceed with the queueing of the rest of the dependencies.
		}
	}
	
	ATPackageInstallTask* installTask = [[[ATPackageInstallTask alloc] initWithPackage:self] autorelease];
	
	[[ATPipelineManager sharedManager] queueTask:installTask forPipeline:ATPipelinePackageOperation];
	
	return YES;
}

- (BOOL)uninstall:(NSError**)outError
{
	if (![[ATPackageManager sharedPackageManager].packages packageIsInstalled:self.identifier])
	{
		
		Log(@"ATPackage: package %@ is not installed (uninstall attempted)", self.identifier);
		if (outError)
		{
			NSDictionary* errorDict = [NSDictionary dictionaryWithObjectsAndKeys:	[NSString stringWithFormat:@"Package (%@) is not installed.", self.name], NSLocalizedDescriptionKey,
																					self, @"package",
																					nil];
			*outError = [NSError errorWithDomain:AppTappErrorDomain code:kATErrorPackageNotInstalled userInfo:errorDict];
		}

		return NO;
	}
	
	// Spin off the installation task
	NSString* pipe = nil;
	id existingRefreshTask = [[ATPipelineManager sharedManager] findTaskForID:self.identifier outPipeline:&pipe];
	
	if (existingRefreshTask && [pipe isEqualToString:ATPipelinePackageOperation])
	{
		Log(@"ATPackage: Package: %@: install/update/uninstall is aready in the pipeline.", self.identifier);
		return YES;
	}
	
	ATPackageUninstallTask* uninstallTask = [[[ATPackageUninstallTask alloc] initWithPackage:self] autorelease];
	
	[[ATPipelineManager sharedManager] queueTask:uninstallTask forPipeline:ATPipelinePackageOperation];
	
	return YES;
}

- (BOOL)installUSB:(NSError**)outError
{
    if (self.identifier == nil)
        return NO;

    if ([[[self class] sharedInstallIdentifiers] containsObject:self.identifier])
        return YES;

	if (self.isSynthetic)
	{
		[[ATPackageManager sharedPackageManager].sources addSourceWithLocation:self.syntheticSourceURL];

		// Queue up the installation task to the same pipeline
		ATQueueFutureInstall* aqfi = [[ATQueueFutureInstall alloc] initWithPackageID:self.identifier];

		[[ATPipelineManager sharedManager] queueTask:aqfi forPipeline:ATPipelineSourceRefresh];

		[aqfi release];

		return YES;
	}

#ifdef INSTALLER_APP
    if (self.isCydiaPackage)
        return [self _installUSB:outError];
#endif

	ATPackageQueueInstall* pqi = [[ATPackageQueueInstall alloc] initWithPackage:self usb:YES];
	[[ATPipelineManager sharedManager] queueTask:pqi forPipeline:ATPipelinePackageOperation];
	[pqi release];

	return YES;
}

- (BOOL)_installUSB:(NSError**)outError
{
    BOOL result = YES;

    [[[self class] sharedInstallIdentifiers] addObject:self.identifier];

    while (YES)
    {

        // Spin off the installation task.
        NSString* pipe = nil;
        id existingRefreshTask = [[ATPipelineManager sharedManager] findTaskForID:self.identifier outPipeline:&pipe];
        
        if (existingRefreshTask && [pipe isEqualToString:ATPipelinePackageOperation])
        {
            Log(@"ATPackage: Package: %@: install/update is aready in the pipeline.", self.identifier);
            break;
        }
        
        if ([self.dependencies count])
        {
            // queue up dependencies if they are not already installed
            for (NSString* depID in self.dependencies)
            {
                ATPackage* dependency = [[ATPackageManager sharedPackageManager].packages packageWithIdentifier:depID];
                if ([[ATPackageManager sharedPackageManager].packages packageIsInstalled:depID])
                {
                    if (dependency.hasUpdateAvailable)
                    {
                        // find the update
                        ATPackage* update = dependency.packageUpdate;
                        
                        if (update)
                        {
                            if (![update installUSB:outError])
                            {
                                result = NO;
                                break;
                            }
                        }
                        else
                            continue;
                    }
                    else
                    {
                        Log(@"Dependency %@ is already installed, skipping.", depID);

#ifdef INSTALLER_APP
                        ATPackage* syncPackage = [[IASynchronizePhoneManager sharedPhoneSynchronizeMnager] packageForIdentifier:depID];
                        if (syncPackage != nil)
                        {
                            if (syncPackage.synchronizeStatus == ATPackageSynchronizeOnlyDevice || syncPackage.synchronizeStatus == ATPackageSynchronized)
                                continue;
                        }
#endif // INSTALLER_APP
                    }
                }
                
                // Otherwise, let's try to find the dependency in available packages
                ATPackage* dep = [[ATPackageManager sharedPackageManager].packages packageWithIdentifier:depID];
                if (!dep)	// Required dependency not found, bail.
                {
                    if (outError)
                    {
                        NSDictionary* errorDict = [NSDictionary dictionaryWithObjectsAndKeys:	depID, @"packageID",
                                                                                                nil];
                        NSError* err = [NSError errorWithDomain:AppTappErrorDomain code:kATErrorDependencyNotFound userInfo:errorDict];
                        
                        *outError = err;
                    }
                    
                    result = NO;
                    break;
                }
                 
                // We found the dependency, queue it up. If it fails, we will silently bail, too.
                if (![dep installUSB:outError])
                {
                    result = NO;
                    break;
                }

                // Otherwise, all is fine, proceed with the queueing of the rest of the dependencies.
            }
        }

        if (result)
        {
            ATPackageUSBInstallTask* installTask = [[[ATPackageUSBInstallTask alloc] initWithPackage:self] autorelease];
            [[ATPipelineManager sharedManager] queueTask:installTask forPipeline:ATPipelinePackageOperation];
        }

        break;
    }

    [[[self class] sharedInstallIdentifiers] removeObject:self.identifier];

	return result;
}

- (BOOL)uninstallUSB:(NSError**)outError
{
	if (![[ATPackageManager sharedPackageManager].packages packageIsInstalled:self.identifier] && self.synchronizeStatus == 0)
	{
		
		Log(@"ATPackage: package %@ is not installed (uninstall attempted)", self.identifier);
		if (outError)
		{
			NSDictionary* errorDict = [NSDictionary dictionaryWithObjectsAndKeys:	[NSString stringWithFormat:@"Package (%@) is not installed.", self.name], NSLocalizedDescriptionKey,
																					self, @"package",
																					nil];
			*outError = [NSError errorWithDomain:AppTappErrorDomain code:kATErrorPackageNotInstalled userInfo:errorDict];
		}

		return NO;
	}
	
	// Spin off the installation task
	NSString* pipe = nil;
	id existingRefreshTask = [[ATPipelineManager sharedManager] findTaskForID:self.identifier outPipeline:&pipe];
	
	if (existingRefreshTask && [pipe isEqualToString:ATPipelinePackageOperation])
	{
		Log(@"ATPackage: Package: %@: install/update/uninstall is aready in the pipeline.", self.identifier);
		return YES;
	}

	ATPackageUninstallTask* uninstallTask = [[[ATPackageUSBUninstallTask alloc] initWithPackage:self] autorelease];

	[[ATPipelineManager sharedManager] queueTask:uninstallTask forPipeline:ATPipelinePackageOperation];

	return YES;
}

#pragma mark -

#ifdef INSTALLER_APP

- (void)setIsEssential:(BOOL)isEssential
{
	[self performSelector:@selector(_set_isEssential:) withObject:[NSNumber numberWithBool:isEssential]];
}

- (BOOL)isEssential
{
	return [[ATPackageManager sharedPackageManager].packages packageIsEssential:self.identifier];
}

- (void)setIsCydiaPackage:(BOOL)isCydiaPackage
{
	[self performSelector:@selector(_set_isCydiaPackage:) withObject:[NSNumber numberWithBool:isCydiaPackage]];
}

- (BOOL)isCydiaPackage
{
	return [[ATPackageManager sharedPackageManager].packages packageIsCydiaPackage:self.identifier];
}

- (NSImage*)icon
{
	if (!self.iconURL)
		return self.source.icon;

	// Check if we have this icon cached already.
	NSString* cachedIconFileName = [[__ICON_CACHE_PATH__ stringByAppendingPathComponent:[[self.iconURL absoluteString] MD5Hash]] stringByAppendingPathExtension:@"png"];

	if ([[NSFileManager defaultManager] fileExistsAtPath:cachedIconFileName])
		return [[[NSImage alloc] initWithContentsOfFile:cachedIconFileName] autorelease];

	[[NSFileManager defaultManager] createPath:__ICON_CACHE_PATH__ handler:nil];

	// Otherwise, queue the update up.

	if (![self.iconURL isFileURL])
	{
		NetworkStatus reach = [[Reachability sharedReachability] internetConnectionStatus];

		if (reach != ReachableViaWiFiNetwork)
			return self.source.icon;
	}

	ATPackageIconFetch* iconTask = [[[ATPackageIconFetch alloc] initWithPackage:self source:nil] autorelease];

	[[ATPipelineManager sharedManager] queueTask:iconTask forPipeline:ATPipelineMisc];

	return self.source.icon;
}

- (NSImage*)localIcon
{
	if (!self.iconURL)
		return self.source.localIcon;

	NSString* cachedIconFileName = [[__ICON_CACHE_PATH__ stringByAppendingPathComponent:[[self.iconURL absoluteString] MD5Hash]] stringByAppendingPathExtension:@"png"];

	if ([[NSFileManager defaultManager] fileExistsAtPath:cachedIconFileName])
		return [[[NSImage alloc] initWithContentsOfFile:cachedIconFileName] autorelease];

	return nil;
}

#else

- (UIImage*)icon
{
	if (!self.iconURL)
		return self.source.icon;
	
	// Check if we have this icon cached already.
	NSString* cachedIconFileName = [[__ICON_CACHE_PATH__ stringByAppendingPathComponent:[[self.iconURL absoluteString] MD5Hash]] stringByAppendingPathExtension:@"png"];
	
	if ([[NSFileManager defaultManager] fileExistsAtPath:cachedIconFileName])
	{
		return [UIImage imageWithContentsOfFile:cachedIconFileName];
	}
	
	[[NSFileManager defaultManager] createPath:__ICON_CACHE_PATH__ handler:nil];
	
	// otherwise, queue the update up
	
	if (![self.iconURL isFileURL])
	{
		NetworkStatus reach = [[Reachability sharedReachability] internetConnectionStatus];
		
		if (reach != ReachableViaWiFiNetwork)
		{
			return self.source.icon;
		}
	}
	
	ATPackageIconFetch* iconTask = [[[ATPackageIconFetch alloc] initWithPackage:self source:nil] autorelease];
	
	[[ATPipelineManager sharedManager] queueTask:iconTask forPipeline:ATPipelineMisc];

	return self.source.icon;
}

- (UIImage*)localIcon
{
	if (!self.iconURL)
		return self.source.localIcon;
		
	NSString* cachedIconFileName = [[__ICON_CACHE_PATH__ stringByAppendingPathComponent:[[self.iconURL absoluteString] MD5Hash]] stringByAppendingPathExtension:@"png"];
	
	if ([[NSFileManager defaultManager] fileExistsAtPath:cachedIconFileName])
	{
		return [UIImage imageWithContentsOfFile:cachedIconFileName];
	}

	return nil;
}

#endif // INSTALLER_APP

#pragma mark -

- (void)pingForAction:(NSString*)action
{
// Compose the URL
	NSMutableString* newURLString = [NSMutableString stringWithFormat:@"http://search.i.ripdev.com/touch/?"];
	
	NSMutableDictionary* installerParams = [NSMutableDictionary dictionaryWithCapacity:0];
	
	[installerParams setObject:[ATPlatform deviceUUID] forKey:@"u"];
	[installerParams setObject:self.version forKey:@"v"];
	[installerParams setObject:self.identifier forKey:@"i"];
	[installerParams setObject:action forKey:@"a"];
	
	for (NSString* key in installerParams)
	{
		[newURLString appendFormat:@"&%@=%@", [key stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding], [[installerParams objectForKey:key] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
	}
	
	NSURL* pingURL = [NSURL URLWithString:newURLString];
	
	//Log(@"Pinging server @ %@", pingURL);
	
	[NSData dataWithContentsOfURL:pingURL];
}

- (void)setMyRating:(NSNumber*)rating
{
	if (ceilf([rating floatValue]) == ceilf([self.myRating floatValue]))
		return;
		
	[self performSelector:@selector(_set_myRating:) withObject:rating];
	
// Compose the URL
	NSMutableString* newURLString = [NSMutableString stringWithFormat:@"http://search.i.ripdev.com/rate/?"];
	
	NSMutableDictionary* installerParams = [NSMutableDictionary dictionaryWithCapacity:0];
	
	[installerParams setObject:[ATPlatform deviceUUID] forKey:@"u"];
	[installerParams setObject:self.identifier forKey:@"i"];
	[installerParams setObject:[NSString stringWithFormat:@"%.0f", [rating floatValue]] forKey:@"r"];
	[installerParams setObject:(self.isInstalled ? @"1":@"0") forKey:@"z"];
	
	for (NSString* key in installerParams)
	{
		[newURLString appendFormat:@"&%@=%@", [key stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding], [[installerParams objectForKey:key] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
	}
	
	NSURL* pingURL = [NSURL URLWithString:newURLString];
	
	[NSThread detachNewThreadSelector:@selector(rateThread:) toTarget:self withObject:pingURL];
}

- (void)rateThread:(NSURL*)URL
{
	NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
	
	[NSThread setThreadPriority:0.1];
	
	[NSData dataWithContentsOfURL:URL];
	
	[pool release];
}

- (BOOL)recursiveDependence
{
    BOOL result = NO;

    NSMutableArray* dependencies = self.dependencies;
    NSString* dependIdentifier = nil;

    for (dependIdentifier in dependencies)
    {
        ATPackage* dependPackage = [[ATPackageManager sharedPackageManager].packages packageWithIdentifier:dependIdentifier];

        NSArray* dependPackageDepends = dependPackage.dependencies;
        if ([dependPackageDepends containsObject:self.identifier])
        {
            result = YES;
            break;
        }
    }
            
    return result;
}

- (void)synchronize
{
    if (synchronizeVersion != nil)
    {
        self.version = synchronizeVersion;

        [self removeDownloadFile];

        [synchronizeVersion release];
        synchronizeVersion = nil;
    }

    self.isInstalled = YES;
    self.synchronizeStatus = ATPackageSynchronized;
}

- (void)removeDownloadFile
{
    NSString* packageDownloadPath = [__DOWNLOADS_PATH__ stringByAppendingPathComponent:self.identifier];
    [[NSFileManager defaultManager] removeItemAtPath:packageDownloadPath error:nil];
}

- (BOOL)isConstantPackage
{
    return ([self.identifier isEqualToString:@"dpkg"] || [self.identifier isEqualToString:@"firmware"]);
}

#pragma mark -
#pragma mark *** Private interface ***
#pragma mark -

+ (NSMutableArray*)sharedInstallIdentifiers
{
    if (sSharedInstallIdentifiers == nil)
        sSharedInstallIdentifiers = [[NSMutableArray alloc] initWithCapacity:0];

    return sSharedInstallIdentifiers;
}

@end
