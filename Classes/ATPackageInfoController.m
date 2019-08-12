#import "ATPackageInfoController.h"
#import "ATPackage.h"
#import "ATEmitErrorTask.h"
#import "ATPipelineManager.h"
#import "ATRatingFetchTask.h"

@implementation ATPackageInfoController
- (IBAction)moreInfoButtonPressed:(id)sender {
	
	moreInfoView.package = package;
	moreInfoView.urlToLoad = package.url;
	moreInfoView.navigationItem.title = package.name;
	
	[self.navigationController pushViewController:moreInfoView animated:YES];
    
}

- (IBAction)sponsorButtonPressed:(id)sender
{
	moreInfoView.package = package;
	moreInfoView.urlToLoad = package.sponsorURL;
	
	[self.navigationController pushViewController:moreInfoView animated:YES];	
}

- (IBAction)sourceInfoButtonPressed:(id)sender {
	sourceInfoView.source = package.source;
	
	[self.navigationController pushViewController:sourceInfoView animated:YES];
}

- (IBAction)mailButtonPressed:(id)sender
{
	if (package.contact)
	{
		NSURL* contact = [NSURL URLWithString:[NSString stringWithFormat:@"mailto:%@?subject=%@", package.contact, [[NSString stringWithFormat:@"Regarding package %@", package.name] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]]];
		
		[[UIApplication sharedApplication] openURL:contact];
	}
}

- (IBAction)installButtonPressed:(id)sender {
	NSError* err = nil;
	
	if (self.package.isSynthetic)
	{
		// Present an alert sheet to the user for synthetic packages
		UIActionSheet* as = [[[UIActionSheet alloc] initWithTitle:[NSString stringWithFormat:NSLocalizedString(@"The package \"%@\" comes from a source that is not yet added to Installer. If you Proceed, the source \"%@\" will be first added to your sources list, and then the package will be installed as normal.", @""), self.package.name, self.package.syntheticSourceName] delegate:self cancelButtonTitle:NSLocalizedString(@"Cancel", @"") destructiveButtonTitle:NSLocalizedString(@"Proceed", @"") otherButtonTitles:nil] autorelease];
		
		[as showInView:self.view];
		
		return;
	}
	
	if ([package.identifier isEqualToString:__INSTALLER_BUNDLE_IDENTIFIER__] || [[ATPackageManager sharedPackageManager].packages.customQuery length] || !package.isInstalled)
		[package install:&err];
	else
		[package uninstall:&err];
		
	if (err)
	{
		// This may look awkward, but it's what it is - we spawn a new fake task that does nothing but reports an error...
		ATEmitErrorTask* errTask = [[ATEmitErrorTask alloc] initWithError:err];
		[[ATPipelineManager sharedManager] queueTask:errTask forPipeline:ATPipelineErrors];
		[errTask release];
	}
	
    [self.navigationController popViewControllerAnimated:YES];
}

@synthesize package;

-(void) viewDidLoad
{
	iconView = [[ATIconView alloc] initWithFrame:CGRectMake(15, 10, 80, 105)];
	[iconView setIcon:[UIImage imageNamed:@"SampleIcon.png"]];
	[self.view addSubview:iconView];
	
	installButton = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Install", @"")
													 style:UIBarButtonItemStylePlain
													 target:self 
													 action:@selector(installButtonPressed:)];
	uninstallButton = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Uninstall", @"")
													 style:UIBarButtonItemStylePlain
													target:self 
													action:@selector(installButtonPressed:)];
	updateButton = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Update", @"")
													   style:UIBarButtonItemStylePlain
													  target:self 
													  action:@selector(installButtonPressed:)];
													  
	[[NSNotificationCenter defaultCenter] addObserver:self 
										 selector:@selector(ratingChangedNotification:) 
											 name:ATPackageInfoRatingChangedNotification 
										   object:nil];

}

- (void) viewWillAppear:(BOOL)animated
{
	UIImage *icon = package.icon;
	
	[iconView setIcon:icon];
	iconView.drawShadow = YES;
	
	[iconView setTrusted:[package isTrustedPackage]];
	[iconView setNew:[package isNewPackage]];
	
	[packageNameLabel setText:package.name];
	
	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"ShowPackageID"])
		[packageDescriptionLabel setText:[NSString stringWithFormat:@"%@\n\nPackage ID: %@", package.description, package.identifier]];
	else
		[packageDescriptionLabel setText:package.description];

	if ([package.size longValue])
		[packageSizeLabel setText:[NSString stringWithFormat:@"%d Kb", (int)[package.size longValue] / 1024]];
	else
		[packageSizeLabel setText:@""];
	
	if (package.isSynthetic)
		[packageSourceLabel setText:[NSString stringWithFormat:@"%@: %@", NSLocalizedString(@"Source", @""), package.syntheticSourceName]];
	else
		[packageSourceLabel setText:[NSString stringWithFormat:@"%@: %@", NSLocalizedString(@"Source", @""), package.source.name]];
	
	if(package.version != nil)
		[packageVersionLabel setText:package.version];
	else
		[packageVersionLabel setText:@""];
	
	ratingView.userRating = [package.rating floatValue];
	ratingView.myRating = [package.myRating floatValue];
	[ratingView setNeedsDisplay];
	
	NSDateFormatter *dateFormat = [[[NSDateFormatter alloc] init] autorelease];
	[dateFormat setDateStyle:NSDateFormatterShortStyle];
	
	NSString *dateStr = [dateFormat stringFromDate:package.date];
	if(dateStr == nil || [dateStr length] == 0)
		[packageDateLabel setText:@""];
	else
		[packageDateLabel setText:dateStr];
	
	NSString* contact = package.maintainer;
	
	if (!contact)
		contact = package.contact;
	
	if (!contact || ![contact length])
		contact = package.source.contact;
		
	NSString *emailStr = [NSString stringWithFormat:@"%@: %@", NSLocalizedString(@"Contact", @""), contact];
	
	if (package.isSynthetic)
		[packageEMailLabel setText:@""];
	else
		[packageEMailLabel setText:emailStr];
	
	if (package.isSynthetic)
	{
		movingMailButton.hidden = YES;
		sourceInfoButton.hidden = YES;
	}
	else
	{
		movingMailButton.hidden = NO;
		sourceInfoButton.hidden = NO;
	}
	
	// More info show hide
	if(package.url == nil)
	{
		[movingMoreInfoLabel setAlpha:0];
		[movingMoreInfoButton setAlpha:0];
	}
	else
	{
		[movingMoreInfoLabel setAlpha:1.0];
		[movingMoreInfoButton setAlpha:1.0];
	}
	
	// Sponsor show/hide
	if (package.sponsor == nil)
	{
		[movingSponsorLabel setAlpha:0];
		[movingSponsorButton setAlpha:0];
	}
	else
	{
		movingSponsorLabel.text = package.sponsor;
		[movingSponsorLabel setAlpha:1];
		[movingSponsorButton setAlpha:(package.sponsorURL == nil) ? 0 : 1];
	}

	// let's see if we are in the updated packages category
	if ([[ATPackageManager sharedPackageManager].packages.customQuery length])
	{
		[self.navigationItem setRightBarButtonItem:updateButton];
	}
	else
	{
		if (![package.identifier isEqualToString:__INSTALLER_BUNDLE_IDENTIFIER__])
		{
			if (package.isInstalled)
			{
				[self.navigationItem setRightBarButtonItem:uninstallButton];
			}
			else
				[self.navigationItem setRightBarButtonItem:installButton];
		}
		else
			[self.navigationItem setRightBarButtonItem:nil];
	}

	// Now readjust the view
	

	CGRect rTemp = packageDescriptionLabel.frame;
	CGSize sz = [packageDescriptionLabel.text	sizeWithFont:packageDescriptionLabel.font 
												constrainedToSize:CGSizeMake(rTemp.size.width, 650)
												lineBreakMode:UILineBreakModeWordWrap];	

	CGFloat sizeDiff = sz.height - rTemp.size.height;
	
	rTemp.size.height = sz.height;
	packageDescriptionLabel.frame = rTemp;
	
	// adjust bottom view frame
	CGRect rTemp2 = movingBottomView.frame;
	rTemp2.origin.y = rTemp.origin.y + rTemp.size.height;
	movingBottomView.frame = rTemp2;

	rTemp = scrollerContentView.frame;
	rTemp.size.height += sizeDiff;
	scrollerContentView.frame = rTemp;
	
	scrollerView.contentSize = rTemp.size;
	
	[scrollerView scrollRectToVisible:CGRectMake(0,0,10,10) animated:NO];
	
	// fetch the rating
	NSDate* lastcheck = self.package.ratingRefresh;
	
	if (lastcheck && fabs([lastcheck timeIntervalSinceNow]) >= (60.*60.*4.))
	{	
		ATRatingFetchTask* fetchTask = [[ATRatingFetchTask alloc] initWithPackage:self.package];
		[[ATPipelineManager sharedManager] queueTask:fetchTask forPipeline:ATPipelineSearch];
		[fetchTask release];
	}

	[super viewWillAppear:animated];
}

-(void)dealloc
{
	[iconView release];
	[super dealloc];
}

#pragma mark -

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex
{
	if (!buttonIndex) // proceed
	{
		[self.package install:nil];
		[self.navigationController popViewControllerAnimated:YES];
	}
}

#pragma mark -

- (void)ratingChanged:(NSNumber*)newRating
{
	self.package.myRating = newRating;
	[self.package commit];
}

- (void)ratingChangedNotification:(NSNotification*)notification
{
	ATPackage* pack = (ATPackage*)[notification object];
	
	if ([self.package.identifier isEqualToString:pack.identifier])
	{
		ratingView.userRating = [package.rating floatValue];
		ratingView.myRating = [package.myRating floatValue];
		[ratingView setNeedsDisplay];		
	}
}
@end
