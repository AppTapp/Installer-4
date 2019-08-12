//
//  ATInstaller.m
//  Installer
//
//  Created by Maksim Rogov on 25/04/08.
//  Copyright Nullriver, Inc. 2008. All rights reserved.
//

#import "ATInstaller.h"
#import "ATPipelineManager.h"
#import "ATPackage.h"
#import "curl/curl.h"

static int sIgnoredCURLErrors[] = {
	CURLE_FILE_COULDNT_READ_FILE,
	CURLE_COULDNT_RESOLVE_HOST,
	CURLE_COULDNT_CONNECT,
	CURLE_WRITE_ERROR,
	0
};

@implementation ATInstaller

ATInstaller * sharedInstaller = nil;

@synthesize window;
@synthesize tabBarController;
@synthesize packageManager;
@synthesize notificationQueue;

+ (ATInstaller *)sharedInstaller {
	return sharedInstaller ? sharedInstaller : [[self alloc] init];
}

- (id)init {
	if(self = [super init]) {
	
		//NSLog(@"ATInsaller = %@ (shared = %@)", self, sharedInstaller);
		
		sharedInstaller = self;
		offeredUpdate = NO;
		
		notificationQueue = [NSNotificationQueue defaultQueue];
				
		// Initialize the package manager
		packageManager = [ATPackageManager sharedPackageManager];
		[packageManager setDelegate:self];

		// Initialize the tab bar
		self.tabBarController = [[[UITabBarController alloc] init] autorelease];
		
		// The progress view
		progressBar = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleBar];
		[progressBar setFrame:CGRectMake(320.0f / 2 - 100.0f, 38.0f, 200.0f, 20.0f)];
		progressSheet = [[UIActionSheet alloc] init];
		[progressSheet addSubview:progressBar];
		[progressSheet setActionSheetStyle:UIActionSheetStyleBlackTranslucent];
		
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(taskDone:) name:ATPipelineTaskFinishedNotification object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(sourceRefreshed:) name:ATSourceUpdatedNotification object:nil];
		
#if !defined(__i386__)
		if (geteuid() != 0)
		{
#if 0
			UIAlertView * failAlert = [[UIAlertView alloc] init];
			failAlert.delegate = self;
			failAlert.title = NSLocalizedString(@"Insufficient Permissions", @"Installer Main");
			failAlert.message = NSLocalizedString(@"Installer was not installed correctly. It should be run as root:wheel. We will continue but please remember that it may not function correctly.", @"Installer Main");
			[failAlert addButtonWithTitle:NSLocalizedString(@"OK", @"")];
			[failAlert setDelegate:self];
			[failAlert show];
#else
			NSLog(@"Running as effective user %d", geteuid());
#endif
		}
#endif
	}
	
	return self;
}

- (void)applicationWillTerminate:(UIApplication *)application
{
	[[ATPackageManager sharedPackageManager] restartSpringBoardIfNeeded];
}

- (void)taskDone:(NSNotification*)notification
{
	static NSError* lastError = nil;
		
	if (![[[notification userInfo] objectForKey:ATPipelineUserInfoSuccess] boolValue])
	{
		NSError* err = [[notification userInfo] objectForKey:ATPipelineUserInfoError];
		
		//NSLog(@"Task done notification error: domain='%@', code = %u, locDesc='%@'", [err domain], [err code], [[err userInfo] objectForKey:NSLocalizedDescriptionKey]);
	
		if ([[err domain] isEqualToString:CURLErrorDomain])
		{
			int code = [err code];
			
			for (int i=0; sIgnoredCURLErrors[i]; i++)
			{
				if (sIgnoredCURLErrors[i] == code)
					return;
			}
		}
		else if ([[err domain] isEqualToString:AppTappErrorDomain] && ![[err userInfo] objectForKey:NSLocalizedDescriptionKey])
		{
			NSString* errorText = [[NSBundle bundleForClass:[self class]] localizedStringForKey:[NSString stringWithFormat:@"%d", [err code]] value:[NSString stringWithFormat:@"Installer Error #%d. Please report the error code to RiP Dev at support@ripdev.com so we can provide a better description for it.", [err code]] table:@"Errors"];
			NSString* errorErrata = nil;
			
			if ([[err userInfo] objectForKey:@"package"])
				errorErrata = ((ATPackage*)[[err userInfo] objectForKey:@"package"]).name;
			else if ([[err userInfo] objectForKey:@"packageID"])
				errorErrata = [[err userInfo] objectForKey:@"packageID"];
			
			NSMutableDictionary* userInfo = [NSMutableDictionary dictionaryWithCapacity:0];
			
			if ([err userInfo])
				[userInfo addEntriesFromDictionary:[err userInfo]];
		
			[userInfo setObject:[NSString stringWithFormat:errorText, errorErrata] forKey:NSLocalizedDescriptionKey];
			
			err = [NSError errorWithDomain:[err domain] code:[err code] userInfo:userInfo];
		}
		
		if (lastError != err)
		{
			NSString* description = [err localizedDescription];
		
			UIAlertView* errorView = [[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Error", @"") message:description delegate:nil cancelButtonTitle:NSLocalizedString(@"OK", @"") otherButtonTitles:nil] autorelease];
			[errorView show];
		
			lastError = err;
		}
	}
}

- (void)sourceRefreshed:(NSNotification*)notification
{
	ATSource* source = (ATSource*)[notification object];
	
	if ([[source.location absoluteString] hasPrefix:@"http://i.ripdev.com"] && !offeredUpdate)
	{
		if ([[ATPackageManager sharedPackageManager].packages hasInstallerUpdate])
		{
			offeredUpdate = YES;
			
			UIAlertView* errorView = [[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Installer Update Available", @"") message:NSLocalizedString(@"An Installer update is available. Would you like to update it now? It is strongly recommended you stay up-to-date with the latest version.", @"") delegate:self cancelButtonTitle:NSLocalizedString(@"Cancel", @"") otherButtonTitles:NSLocalizedString(@"Update", @""), nil] autorelease];
			
			[errorView show];
		}
	}
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
	if (buttonIndex)
	{
		// queue up an update
		ATPackage* installerUpdate = [[ATPackageManager sharedPackageManager].packages hasInstallerUpdate];
		if (installerUpdate)
			[installerUpdate install:nil];
	}
}

- (void)applicationDidFinishLaunching:(UIApplication *)application {	
	// Assign tabview items
	
	featuredViewController.tabBarItem = [[[UITabBarItem alloc] initWithTabBarSystemItem:UITabBarSystemItemFeatured tag:0] autorelease];
	searchTableViewController.tabBarItem = [[[UITabBarItem alloc] initWithTabBarSystemItem:UITabBarSystemItemSearch tag:0] autorelease];
	categoriesTableViewController.tabBarItem.image = [UIImage imageNamed:@"Categories.png"];
	sourcesTableViewController.tabBarItem.image = [UIImage imageNamed:@"Sources.png"];
	tasksTableViewController.tabBarItem.image = [UIImage imageNamed:@"Tasks.png"];
	
	NSArray * viewControllers = [NSArray arrayWithObjects:
								 [[[UINavigationController alloc] initWithRootViewController:featuredViewController] autorelease],
								 [[[UINavigationController alloc] initWithRootViewController:categoriesTableViewController] autorelease],
								 [[[UINavigationController alloc] initWithRootViewController:searchTableViewController] autorelease],
								 [[[UINavigationController alloc] initWithRootViewController:sourcesTableViewController] autorelease],
								 [[[UINavigationController alloc] initWithRootViewController:tasksTableViewController] autorelease],
								 nil];
	
	[tabBarController setViewControllers:viewControllers];
	
	// Add the tab bar controller's current view as a subview of the window
	[window addSubview:tabBarController.view];
	
	// Make the window key and visible
	[window makeKeyAndVisible];
}

- (BOOL)application:(UIApplication *)application handleOpenURL:(NSURL *)url
{
	return [(id<UIWebViewDelegate>)featuredViewController webView:nil shouldStartLoadWithRequest:[NSURLRequest requestWithURL:url] navigationType:UIWebViewNavigationTypeLinkClicked];
}

- (void)tabBarController:(UITabBarController *)tabBarController didSelectViewController:(UIViewController *)viewController {
	// Optional UITabBarControllerDelegate method
}

- (void)tabBarController:(UITabBarController *)tabBarController didEndCustomizingViewControllers:(NSArray *)viewControllers changed:(BOOL)changed {
	// Optional UITabBarControllerDelegate method
}


- (void)dealloc {
	[progressSheet release];
	[progressBar release];

	[tabBarController release];
	[window release];
	[packageManager release];

	[super dealloc];
}


#pragma mark -
#pragma mark Actions

- (IBAction)refreshAllSources:(id)sender {
	[[ATPackageManager sharedPackageManager] refreshAllSources];
}

@end

