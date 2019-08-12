// AppTapp Framework
// Copyright 2007 Nullriver, Inc.

#import "ATPackageManager.h"
#import "ATDatabase.h"
#import "ATPipelineManager.h"
#import "ATSourceRefresh.h"
#import "ATTrustedSourcesRefresh.h"
#import "ATPackage.h"
#import "ATSearch.h"
#import "ATIncompleteDownloads.h"
#import <notify.h>

NSUInteger	gATBehaviorFlags = 0L;

#ifdef INSTALLER_APP_DISABLE_PUSHER
    NSString* const ATPackageManagerFirstLaunchDefaultsKey = @"ATPackageManagerFirstLaunchDefaults";
#endif // INSTALLER_APP_DISABLE_PUSHER

@implementation ATPackageManager

static ATPackageManager * sharedPackageManager = nil;

@synthesize sources;
@synthesize packages;
@synthesize search;
@synthesize springboardNeedsRefresh;
@synthesize springboardNeedsHardRefresh;
@synthesize delegate;
@synthesize scriptCanContinue;
@synthesize scriptConfirmationButton;
@synthesize incompleteDownloads;

@synthesize removedApplications;
@synthesize installedApplications;

#pragma mark -
#pragma mark Factory

+ (ATPackageManager*)sharedPackageManager {
	return sharedPackageManager ? sharedPackageManager : [[self alloc] init];
}

- (id)init {
	if(self = [super init]) {
		sharedPackageManager = self;
		
		curl_global_init(CURL_GLOBAL_SSL);

		//Log(@"ATPackageManager: Initializing...");
		
		// Create our private directory, if it doesn't exist yet
		if(![[NSFileManager defaultManager] fileExistsAtPath:__PRIVATE_PATH__]) {
#ifdef INSTALLER_APP
			[[NSFileManager defaultManager] createDirectoryAtPath:__PRIVATE_PATH__ withIntermediateDirectories:YES attributes:nil error:nil];
#else
			[[NSFileManager defaultManager] createDirectoryAtPath:__PRIVATE_PATH__ withIntermediateDirectories:YES attributes:[NSDictionary dictionaryWithObjectsAndKeys:@"mobile", NSFileOwnerAccountName, @"mobile", NSFileGroupOwnerAccountName, nil] error:nil];
#endif
		}

		// preheat the database connection and force schema check
		[[ATDatabase sharedDatabase] _createOrUpgradeSchema]; 
		
		// Initialize the collection controllers
		sources = [[ATSources alloc] init];
		packages = [[ATPackages alloc] init];
		search = [[ATSearch alloc] init];
		incompleteDownloads = [[ATIncompleteDownloads alloc] init];
		
		self.installedApplications = [NSMutableArray arrayWithCapacity:0];
		self.removedApplications = [NSMutableArray arrayWithCapacity:0];
		
		[incompleteDownloads cleanupTempFolder];
		
		// Register the package sources		
		if(self.sources.count == 0) {
#if defined(INSTALLER_APP)
			NSArray* srcs = [NSArray arrayWithContentsOfURL:__DEFAULT_SOURCES_URL__];
			if (srcs)
			{
				for (NSString* sourceURL in srcs)
				{
					ATSource* newSource = [[ATSource alloc] init];
					NSURL* surl = [NSURL URLWithString:sourceURL];
					
					if (!surl || ![surl host])
						continue;
						
					newSource.name = [surl host];
					newSource.location = surl;
					[newSource commit];
					[newSource release];
				}
			}
			else
#endif
				[[self defaultSource] commit];
		}

		self.springboardNeedsRefresh = NO;
		self.springboardNeedsHardRefresh = NO;
		
        BOOL forceRefresh = NO;

#ifdef INSTALLER_APP_DISABLE_PUSHER
        if (![[NSUserDefaults standardUserDefaults] boolForKey:ATPackageManagerFirstLaunchDefaultsKey])
        {
            [[ATDatabase sharedDatabase] executeUpdate:@"DELETE FROM packages;"];
            forceRefresh = YES;

            [[NSUserDefaults standardUserDefaults] setBool:YES forKey:ATPackageManagerFirstLaunchDefaultsKey];
        }
#endif // INSTALLER_APP_DISABLE_PUSHER

		if ([self refreshIsNeeded] || forceRefresh)
			[self performSelector:@selector(refreshAllSources) withObject:nil afterDelay:3.];
		
		// Check for installer in the database
		BOOL found = NO;
		NSArray* installerPacks = [self.packages packagesWithIdentifier:__INSTALLER_BUNDLE_IDENTIFIER__];
		if (installerPacks)
		{
			unsigned long long currentVersion = [__INSTALLER_VERSION__ versionNumber];
			
			for (ATPackage* pack in installerPacks)
			{
				unsigned long long vers = [pack.version versionNumber];
				
				if (vers == currentVersion)
				{
					found = YES;
					break;
				}
			}
		}
		
		if (!found)
		{
#ifndef INSTALLER_APP
			ATPackage* installerPack = [[ATPackage alloc] init];
			
			installerPack.identifier = __INSTALLER_BUNDLE_IDENTIFIER__;
			installerPack.name = __INSTALLER_NAME__;
			installerPack.version = __INSTALLER_VERSION__;
			installerPack.category = __INSTALLER_CATEGORY__;
			installerPack.location = [NSURL URLWithString:@"file:///"];
			installerPack.description = __INSTALLER_DESCRIPTION__;
			installerPack.contact = __INSTALLER_CONTACT__;
			installerPack.date = [NSDate date];
			installerPack.isInstalled = YES;
			installerPack.source = [self.sources sourceWithLocation:__DEFAULT_SOURCE_LOCATION__];
			installerPack.iconURL = [NSURL fileURLWithPath:[[NSBundle bundleForClass:[self class]] pathForResource:@"Installer" ofType:@"png"]];
			
			[installerPack commit];
			
			[installerPack release];
#endif // INSTALLER_APP
		}
		
		[[ATDatabase sharedDatabase] executeUpdate:@"DELETE FROM packages WHERE identifier = ? AND version <> ?", __INSTALLER_BUNDLE_IDENTIFIER__, __INSTALLER_VERSION__, nil];
	}

	return self;
}

- (void)dealloc {
	[sources release];
	[packages release];
	[search release];

	[super dealloc];
}


#pragma mark -
#pragma mark Accessors

- (ATSource *)defaultSource {
	ATSource * defaultSource = [[[ATSource alloc] init] autorelease];
	
	defaultSource.name = __DEFAULT_SOURCE_NAME__;
	defaultSource.location = [NSURL URLWithString:__DEFAULT_SOURCE_LOCATION__];
	defaultSource.maintainer = __DEFAULT_SOURCE_MAINTAINER__;
	defaultSource.contact = __DEFAULT_SOURCE_CONTACT__;
	
	return defaultSource;
}

- (BOOL)refreshIsNeeded {
	if (gATBehaviorFlags & kATBehavior_NoNetwork)
		return NO;
	
	NSDate * lastRefreshDate = [InstallerPreferences objectForKey:@"lastRefreshDate"];

	if(lastRefreshDate == nil) return YES;

	NSDate * nextRefreshDate = [NSDate dateWithTimeIntervalSince1970:[lastRefreshDate timeIntervalSince1970] + __REFRESH_INTERVAL__];
	NSDate * currentDate = [NSDate date];

	//Log(@"last refresh = %@, next = %@, current = %@", lastRefreshDate, nextRefreshDate, currentDate);
	
	if(
		packages.count == 0 ||
		[nextRefreshDate laterDate:currentDate] == currentDate ||
		[lastRefreshDate laterDate:currentDate] == lastRefreshDate
	) {
		return YES;
	} else {
		return NO;
	}
}

- (void)updateApplicationBadge
{
	int updatedCount = [[ATPackageManager sharedPackageManager].packages countOfUpdatedPackages];

#ifdef INSTALLER_APP
    if ([NSApp respondsToSelector:@selector(dockTile)])
    {
        if (updatedCount > 0)
            [[NSApp dockTile] setBadgeLabel:[NSString stringWithFormat:@"%d", updatedCount]];
        else
            [[NSApp dockTile] setBadgeLabel:nil];
    }
#else
	if (updatedCount > 0)
		[UIApplication sharedApplication].applicationIconBadgeNumber = updatedCount;
	else
	{
		if ([[UIApplication sharedApplication] respondsToSelector:@selector(removeApplicationBadge)])
			[[UIApplication sharedApplication] performSelector:@selector(removeApplicationBadge) withObject:nil];
	}
#endif // INSTALLER_APP
}

#pragma mark -
#pragma mark Refreshing

- (BOOL)refreshTrustedSources {
	return [[ATPipelineManager sharedManager] queueTask:[[[ATTrustedSourcesRefresh alloc] init] autorelease] forPipeline:ATPipelineSourceRefresh];
}

- (BOOL)refreshAllSources {
	int totalSources = self.sources.count;
	int z;
	NSMutableArray* sourcesToRefresh = [NSMutableArray arrayWithCapacity:0];
	
	if (gATBehaviorFlags & kATBehavior_NoNetwork)
		return NO;

	for (z=totalSources-1; z>=0; z--)
	{
		// Make sure we try to refresh failed sources only once every 6 hours
/*		if ([[self.sources sourceAtIndex:z].hasErrors boolValue])
		{
			NSDate* lastref = ((ATSource*)[self.sources sourceAtIndex:z]).lastrefresh;
			
			if (lastref && fabs([lastref timeIntervalSinceNow]) < (60.*15.))
			{
				continue;
			}
		} */
			
		[sourcesToRefresh addObject:[self.sources sourceAtIndex:z]];
	}
	
	for (ATSource* src in sourcesToRefresh)
	{
		[self refreshSource:src];
	}
	
	[self refreshTrustedSources];

	[InstallerPreferences setObject:[NSDate date] forKey:@"lastRefreshDate"];
	
	return YES;
}

- (BOOL)refreshSource:(ATSource *)aSource {
	Log(@"ATPackageManager: Refreshing source: %@", aSource.location);

	return [[ATPipelineManager sharedManager] queueTask:[ATSourceRefresh sourceRefreshWithSource:aSource] forPipeline:ATPipelineSourceRefresh];
}

- (void)restartSpringBoardIfNeeded {
	if(self.springboardNeedsRefresh || self.springboardNeedsHardRefresh) {
		if ([[NSFileManager defaultManager] fileExistsAtPath:[@"/var/mobile/Library/Caches/com.apple.mobile.installation.plist" stringByExpandingTildeInPath]])
			[self propogateMobileInstallation];
		else
			notify_post("com.apple.language.changed");
			
		self.springboardNeedsHardRefresh = NO;
	}
}

#pragma mark -
#pragma mark Mobile Installation crap

- (void)propogateMobileInstallation
{
	NSDictionary* cache = [NSDictionary dictionaryWithContentsOfFile:[@"/var/mobile/Library/Caches/com.apple.mobile.installation.plist" stringByExpandingTildeInPath]];
	
	if (cache)
	{
		NSMutableDictionary* mutableCache = [NSMutableDictionary dictionaryWithDictionary:cache];
		
		id systemApps = [mutableCache objectForKey:@"System"];
		
		if ([systemApps isKindOfClass:[NSArray class]])
		{
			// We'll just nuke it for 2.0.2
			[[NSFileManager defaultManager] removeItemAtPath:[@"/var/mobile/Library/Caches/com.apple.mobile.installation.plist" stringByExpandingTildeInPath] error:nil];
			notify_post("com.apple.language.changed");
			
			return;
		}
		else
		{
			// post-2.1 had the dictionary
			NSMutableDictionary* sysApps = [NSMutableDictionary dictionaryWithCapacity:0];
			[sysApps addEntriesFromDictionary:systemApps];
			
			for (NSDictionary* app in self.installedApplications)
			{
				NSString* identifier = [app objectForKey:@"CFBundleIdentifier"];
				
				if (!identifier)
					continue;
				
				if ([sysApps objectForKey:identifier])
					continue;		// already installed, skip
				
				//Log(@"Mobile installation: adding app %@", identifier);
				NSMutableDictionary* app2 = [NSMutableDictionary dictionaryWithDictionary:app];
				[app2 setObject:@"System" forKey:@"ApplicationType"];
				[sysApps setObject:app2 forKey:identifier];
			}
			
			// Now remove removed apps
			for (NSDictionary* app in self.removedApplications)
			{
				NSString* identifier = [app objectForKey:@"CFBundleIdentifier"];
				
				if (!identifier)
					continue;
					
				if (![sysApps objectForKey:identifier])
					continue;		// already not installed, skip
				
				//Log(@"Mobile installation: removing app %@", identifier);
				[sysApps removeObjectForKey:identifier];
			}
			
			[mutableCache setObject:sysApps forKey:@"System"];
		}
		
		[mutableCache writeToFile:[@"/var/mobile/Library/Caches/com.apple.mobile.installation.plist" stringByExpandingTildeInPath] atomically:YES];
		
		notify_post("com.apple.mobile.application_installed");
	}
	
	if (self.springboardNeedsHardRefresh)
	{
		self.springboardNeedsHardRefresh = NO;
		notify_post("com.apple.language.changed");
	}
}

#pragma mark -
#pragma mark ATScript Delegate bits

- (void)scriptIssueNotice:(ATScript*)script notice:(NSString*)notice
{
	self.scriptCanContinue = NO;
	
#ifdef INSTALLER_APP
#else
	if (gATBehaviorFlags & kATBehavior_NoGUI)
	{
		self.scriptCanContinue = YES;
		self.scriptConfirmationButton = 0;
		return;
	}

	UIAlertView* aview = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Notice", @"") message:notice delegate:self cancelButtonTitle:NSLocalizedString(@"OK", @"") otherButtonTitles:nil];
	
	[aview show];
	[aview release];
#endif // INSTALLER_APP
}

- (void)scriptIssueError:(ATScript*)script error:(NSString*)error
{
	self.scriptCanContinue = NO;
	
#ifdef INSTALLER_APP
#else
	if (gATBehaviorFlags & kATBehavior_NoGUI)
	{
		self.scriptCanContinue = YES;
		self.scriptConfirmationButton = 0;
		return;
	}

	UIAlertView* aview = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Error", @"") message:error delegate:self cancelButtonTitle:NSLocalizedString(@"Cancel", @"") otherButtonTitles:nil];
	
	[aview show];
	[aview release];
#endif // INSTALLER_APP
}

- (void)scriptIssueConfirmation:(ATScript*)script arguments:(NSArray*)args
{
	self.scriptCanContinue = NO;
	
#ifdef INSTALLER_APP
#else
	if (gATBehaviorFlags & kATBehavior_NoGUI)
	{
		self.scriptCanContinue = YES;
		self.scriptConfirmationButton = 0;
		return;
	}
	
	UIAlertView* aview = [[UIAlertView alloc] init];
	
	aview.delegate = self;
	aview.message = [args objectAtIndex:0];
	[aview addButtonWithTitle:[args objectAtIndex:2]];
	[aview addButtonWithTitle:[args objectAtIndex:1]];
	
	[aview show];
	[aview release];
#endif // INSTALLER_APP
}

- (NSNumber*)scriptCanContinue:(ATScript*)script
{
	return [NSNumber numberWithBool:self.scriptCanContinue];
}

- (NSNumber*)scriptConfirmationButton:(ATScript*)script
{
	return [NSNumber numberWithUnsignedInt:self.scriptConfirmationButton];
}

#ifdef INSTALLER_APP
#else
- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex
{
	self.scriptConfirmationButton = buttonIndex;
	self.scriptCanContinue = YES;
}
#endif // INSTALLER_APP

@end
