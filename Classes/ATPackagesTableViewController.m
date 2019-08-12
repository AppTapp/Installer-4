//
//  ATPackagesTableViewController.m
//  Installer
//
//  Created by Maksim Rogov on 12/07/08.
//  Copyright 2008 Nullriver, Inc.. All rights reserved.
//

#import "ATPackagesTableViewController.h"
#import "ATEmitErrorTask.h"
#import "ATPipelineManager.h"

NSString* kCategorySpecial_AllPackages = @"__ALL_PACKAGES__";
NSString* kCategorySpecial_InstalledPackages = @"__INSTALLED_PACKAGES__";
NSString* kCategorySpecial_RecentPackages = @"__RECENT_PACKAGES__";
NSString* kCategorySpecial_UpdatedPackages = @"__UPDATED_PACKAGES__";

@implementation ATPackagesTableViewController

@synthesize category;

- (id)initWithCoder:(NSCoder *)decoder {
	if(self = [super initWithCoder:decoder]) {
		fetchCellNumber = -1;
		fetchCell = nil;		
		
		[[NSNotificationCenter defaultCenter] addObserver:self 
												 selector:@selector(fetchDone:) 
													 name:ATPackageInfoDoneFetchingNotification 
												   object:nil];
		
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(sourceRefreshed:) name:ATSourceUpdatedNotification object:nil];
		
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(iconChanged:) name:ATPackageInfoIconChangedNotification object:nil];
	}
	return self;
}

- (void)sourceRefreshed:(NSNotification*)notification
{
	[self performSelector:@selector(viewWillAppear:) withObject:NO afterDelay:2.];
}

- (void)iconChanged:(NSNotification*)notification
{
	ATPackage* package = (ATPackage*)[notification object];
	NSArray* visibleCells = [self.tableView visibleCells];
	
	for (ATPackageCell* ac in visibleCells)
	{
		ATPackage* p = ac.package;
		
		if (p.entryID == package.entryID)
		{
			ac.package = package;	// update it!
			
			[self.tableView setNeedsDisplay];
		}
	}
}

- (void)viewWillAppear:(BOOL)animated {
	self.navigationItem.rightBarButtonItem = nil;
	
	if (self.category == kCategorySpecial_AllPackages)
		[[ATPackageManager sharedPackageManager].packages rebuildWithAllPackagesSortedByCategory];
	else if (self.category == kCategorySpecial_InstalledPackages)
		[[ATPackageManager sharedPackageManager].packages rebuildWithInstalledPackages];
	else if (self.category == kCategorySpecial_RecentPackages)
		[[ATPackageManager sharedPackageManager].packages rebuildWithRecentPackages];
	else if (self.category == kCategorySpecial_UpdatedPackages)
	{
		UIBarButtonItem* updateAllButton = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Update All", @"") style:UIBarButtonItemStylePlain target:self action:@selector(updateAll:)];
		self.navigationItem.rightBarButtonItem = updateAllButton;
		[updateAllButton release];
		[[ATPackageManager sharedPackageManager].packages rebuildWithUpdatedPackages];
		
		self.navigationItem.title = NSLocalizedString(@"Updated", @"");
	}
	else
		[[ATPackageManager sharedPackageManager].packages rebuildWithSelectPackagesSortedAlphabeticallyForCategory:self.category];
	
	[self.tableView reloadData];
}

- (void)dealloc {
	
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
	self.category = nil;
	
	[super dealloc];
}

- (void)updateAll:(id)sender
{
	// Just update all packages
	NSUInteger sectionCount = [[ATPackageManager sharedPackageManager].packages numberOfSections];
	NSUInteger z;
	
	for (z=0;z<sectionCount;z++)
	{
		NSUInteger count = [[ATPackageManager sharedPackageManager].packages numberOfPackagesInSection:z];
		NSUInteger i;
	
		for (i=0; i<count; i++)
		{
			ATPackage* pack = [[ATPackageManager sharedPackageManager].packages packageAtIndex:i ofSection:z];
			NSError* err = nil;
			
			[pack install:&err];
				
			if (err)
			{
				// This may look awkward, but it's what it is - we spawn a new fake task that does nothing but reports an error...
				ATEmitErrorTask* errTask = [[ATEmitErrorTask alloc] initWithError:err];
				[[ATPipelineManager sharedManager] queueTask:errTask forPipeline:ATPipelineErrors];
				[errTask release];
			}
		}
	}
	
	[self.navigationController popViewControllerAnimated:YES];
}


#pragma mark -
#pragma mark UITableView Delegate/DataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	NSInteger secCount = [[ATPackageManager sharedPackageManager].packages numberOfSections];
	
	if (!secCount)		// this category has no packages in it, but we still need to return 1 for number of sections,
		return 1;		// because NSTableView barfs out if 0 is returned.

	return secCount;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
	return [[ATPackageManager sharedPackageManager].packages trimmedSectionTitleAtIndex:section];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	return [[ATPackageManager sharedPackageManager].packages numberOfPackagesInSection:section];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	ATPackageCell * cell = (ATPackageCell*)[tableView dequeueReusableCellWithIdentifier:@"cell"];
	
	NSInteger row = [indexPath row];
	NSInteger section = [indexPath section];
	ATPackage * package = [[ATPackageManager sharedPackageManager].packages packageAtIndex:row ofSection:section];

	if(cell == nil)
	{
		cell = [[[ATPackageCell alloc] initWithFrame:CGRectZero reuseIdentifier:@"cell" package:package] autorelease];
	}
	else
		[cell setPackage:package];
		
	cell.odd = (row % 2);
	
	[cell setAccessoryType:UITableViewCellAccessoryDisclosureIndicator];
	
	return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	NSUInteger row = [indexPath row];
	ATPackage * package = [[ATPackageManager sharedPackageManager].packages packageAtIndex:row ofSection:[indexPath section]];
	if([package needExtendedInfoFetch])
	{
		UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:indexPath];
		
		[(ATPackageCell*)cell setShowIndicator:YES];
		[cell setSelected:NO animated:YES];
		
		fetchCell = (ATPackageCell*)cell;
		fetchCellNumber = row;
		fetchSection = [indexPath section];
		
		[package fetchExtendedInfo];
	}
	else
	{
		/*if (package.customInfoURL != nil && packageCustomInfoController)
		{
			packageCustomInfoController.package = package;
			packageCustomInfoController.urlToLoad = package.customInfoURL;
			packageCustomInfoController.navigationItem.title = package.name;
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
	if(fetchCellNumber >= 0 && fetchCell != nil)
	{
		ATPackage * package = [notification object];

		package = [ATPackage packageWithID:package.entryID];

		[fetchCell setShowIndicator:NO];
		
		fetchCell = nil;
		fetchCellNumber = -1;
		/*if(package.customInfoURL != nil)
		{
			packageCustomInfoController.package = package;
			packageCustomInfoController.urlToLoad = package.customInfoURL;
			packageCustomInfoController.navigationItem.title = package.name;
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

@end
