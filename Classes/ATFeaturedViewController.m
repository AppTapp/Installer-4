//
//  ATFeaturedViewController.m
//  Installer
//
//  Created by Maksim Rogov on 25/04/08.
//  Copyright Nullriver, Inc. 2008. All rights reserved.
//

#import "ATFeaturedViewController.h"
#import "NSURL+AppTappExtensions.h"
#import "ATPackages.h"
#import "ATPackageManager.h"
#import "ATPackage.h"
#import "ATPackageInfoController.h"
#import "ATPackageMoreInfoView.h"


@implementation ATFeaturedViewController

@synthesize moreInfoPackage;

- (void)viewDidLoad {
	[super viewDidLoad];
	
	self.navigationItem.title = NSLocalizedString(@"Featured", @"");		// #40

	[[NSNotificationCenter defaultCenter] addObserver:self 
											 selector:@selector(fetchDone:) 
												 name:ATPackageInfoDoneFetchingNotification 
											   object:nil];
											   
	[webView setDelegate:self];
	[webView loadRequest:[NSURLRequest requestWithURL:[[NSURL URLWithString:__FEATURED_LOCATION__] URLWithInstallerParameters]]];

	[[NSNotificationCenter defaultCenter] addObserver:self 
											 selector:@selector(fetchDone:) 
												 name:ATPackageInfoDoneFetchingNotification 
											   object:nil];	
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
	self.moreInfoPackage = nil;
	
	[super dealloc];
}

- (IBAction)segmentedControlChanged:(UISegmentedControl*)sender
{
	int idx = sender.selectedSegmentIndex;
	
	if (idx)
	{
		// About box
		[webView loadHTMLString:[self renderAbout] baseURL:[NSURL fileURLWithPath:[[NSBundle mainBundle] resourcePath]]];
	}
	else
	{
		[webView loadRequest:[NSURLRequest requestWithURL:[[NSURL URLWithString:__FEATURED_LOCATION__] URLWithInstallerParameters]]];	
	}
}


#pragma mark -
#pragma mark UIWebView Delegate

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType {
	NSURL * url = [request URL];
		
	if(url && [[url scheme] isEqualToString:@"install"]) {
		NSString * identifier = [url host];
		if(identifier) {
			
			[self showPackageInfo:identifier];
		}
		
		return NO;
	}

	return YES;
}

- (void)showPackageInfo:(NSString*)packageID
{
	ATPackage * package = [[ATPackageManager sharedPackageManager].packages packageWithIdentifier:packageID];
	if (!package)
	{
		// No package, let's try to search for it
		[searchTableController setSearch:[NSString stringWithFormat:@"id:%@", packageID]];
		
		[ATInstaller sharedInstaller].tabBarController.selectedIndex = 2;
		return;
	}
	
	if([package needExtendedInfoFetch])
	{
		self.moreInfoPackage = package;
		[package fetchExtendedInfo];
	}
	else
	{
		/*if (package.customInfoURL != nil && packageCustomInfoController)
		{
			packageCustomInfoController.package = package;
			packageCustomInfoController.urlToLoad = package.customInfoURL;
			packageCustomInfoController.navigationItem.title = package.name;
			packageCustomInfoController.navigationItem.hidesBackButton = NO;
			[self.navigationController pushViewController:packageCustomInfoController animated:YES];
		}
		else */
		{
			packageInfoController.package = package;
			packageInfoController.navigationItem.title = package.name;
			
			[self.navigationController pushViewController:packageInfoController animated:YES];
		}
	}
}

- (void) fetchDone:(NSNotification*)notification
{
	if(self.moreInfoPackage != nil)
	{
		ATPackage * package = [notification object];
		
		self.moreInfoPackage = nil;
		
		/*if(package.customInfoURL != nil)
		{
			packageCustomInfoController.package = package;
			packageCustomInfoController.urlToLoad = package.customInfoURL;
			packageCustomInfoController.navigationItem.title = package.name;
			[self.navigationController pushViewController:packageCustomInfoController animated:YES];
		}
		else*/
		{
			packageInfoController.package = package;
			packageInfoController.navigationItem.title = package.name;
			[self.navigationController pushViewController:packageInfoController animated:YES];
		}
	}
}

#pragma mark -

- (NSString*)renderAbout
{
	NSMutableString* t = [NSMutableString stringWithCapacity:0];
	
	[t setString:[NSString stringWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"about" ofType:@"html"]]];
	
	// Replace!
	[t replaceOccurrencesOfString:@"[[[installer-version]]]" withString:__INSTALLER_VERSION__ options:0 range:NSMakeRange(0, [t length])];
	[t replaceOccurrencesOfString:@"[[[platform-name]]]" withString:[ATPlatform platformName] options:0 range:NSMakeRange(0, [t length])];
	[t replaceOccurrencesOfString:@"[[[firmware-version]]]" withString:[ATPlatform firmwareVersion] options:0 range:NSMakeRange(0, [t length])];
	[t replaceOccurrencesOfString:@"[[[device-uuid]]]" withString:[ATPlatform deviceUUID] options:0 range:NSMakeRange(0, [t length])];
	
	return t;
}

@end
