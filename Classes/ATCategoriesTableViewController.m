//
//  ATCategoriesTableViewController.m
//  Installer
//
//  Created by Maksim Rogov on 11/07/08.
//  Copyright 2008 Nullriver, Inc.. All rights reserved.
//

#import "ATCategoriesTableViewController.h"
#import "ATPackages.h"

@implementation ATCategoriesTableViewController

- (void)viewDidLoad {
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(sourceRefreshed:) name:ATSourceUpdatedNotification object:nil];

	self.tableView.rowHeight = 40;
	
	categoryCache = [[NSMutableArray arrayWithCapacity:0] retain];
	
	[super viewDidLoad];
	
	[self _rebuildCache:nil];
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	
	[self.tableView reloadData];
}

- (void)dealloc
{
	[categoryCache release];
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[super dealloc];
}

- (void)_rebuildCache:(id)sender
{
	[categoryCache removeAllObjects];
	
	[[ATPackageManager sharedPackageManager].packages rebuildWithAllPackagesSortedByCategory];
	
	// Add smart categories
	
	
	NSInteger i;
	
	{
		NSDictionary* dict = [NSDictionary dictionaryWithObjectsAndKeys:	kCategorySpecial_AllPackages,							@"title",
																			[NSNumber numberWithBool:YES],							@"smart",
																			[NSNumber numberWithInt:ATCAtegoriesType_AllPackages],	@"type",
																			nil];
		
		[categoryCache addObject:dict];
	}
	
	NSInteger count = [[ATPackageManager sharedPackageManager].packages countOfUpdatedPackages];
	if (count)
	{
		NSDictionary* dict = [NSDictionary dictionaryWithObjectsAndKeys:	kCategorySpecial_UpdatedPackages,							@"title",
																			[NSNumber numberWithBool:YES],								@"smart",
																			[NSNumber numberWithInt:ATCategoriesTYPE_UpdatedPackages],	@"type",
																			[NSNumber numberWithInt:count],								@"count",
																			nil];
		
		[categoryCache addObject:dict];
	}
	
	{
		NSDictionary* dict = [NSDictionary dictionaryWithObjectsAndKeys:	kCategorySpecial_InstalledPackages,					@"title",
																			[NSNumber numberWithBool:YES],						@"smart",
																			[NSNumber numberWithInt:ATCategoriesTYPE_InstalledPackages],	@"type",
																			nil];
		
		[categoryCache addObject:dict];
	}
	
	{
		NSDictionary* dict = [NSDictionary dictionaryWithObjectsAndKeys:	kCategorySpecial_RecentPackages,					@"title",
																			[NSNumber numberWithBool:YES],						@"smart",
																			[NSNumber numberWithInt:ATCategoriesTYPE_RecentPackages],	@"type",
																			nil];
		
		[categoryCache addObject:dict];
	}
	
	ATPackages* packages = [ATPackageManager sharedPackageManager].packages;

	NSInteger numSections = packages.numberOfSections;
	
	for (i = 0; i < numSections; i++)
	{
		NSString* title = [packages sectionTitleAtIndex:i];
		
		if (!title)
			title = @"";
			
		NSDictionary* dict = [NSDictionary dictionaryWithObjectsAndKeys:	title,												@"title",
																			[NSNumber numberWithBool:NO],						@"smart",
																			[NSNumber numberWithInt:[[ATPackageManager sharedPackageManager].packages countOfPackagesInCategory:title]], @"count",
																			[NSNumber numberWithInt:ATCategoriesTYPE_OtherCategories],	@"type",
																			nil];
		
		[categoryCache addObject:dict];
	}
	
	[[ATPackageManager sharedPackageManager] updateApplicationBadge];
	
	[self.tableView reloadData];
}

- (void)sourceRefreshed:(NSNotification*)notification
{
	[self _rebuildCache:nil];
}

#pragma mark -
#pragma mark Actions

- (IBAction)refreshAllSources:(id)sender {
	[[ATInstaller sharedInstaller] refreshAllSources:self];
}


#pragma mark -
#pragma mark UITableView Delegate/DataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	return [categoryCache count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	NSDictionary* entry = nil;
	ATCategoriesCell* cell = (ATCategoriesCell*)[tableView dequeueReusableCellWithIdentifier:@"cell"];
	
	if (!cell)
		cell = [[[ATCategoriesCell alloc] initWithFrame:CGRectZero reuseIdentifier:@"cell" categoriesType:ATCategoriesTYPE_OtherCategories] autorelease];

	NSInteger row = [indexPath row];
	
	entry = [categoryCache objectAtIndex:row];
	
	NSInteger type = [[entry objectForKey:@"type"] intValue];
	[cell setCategoriesType:type];
	
	NSString * title = [entry objectForKey:@"title"];
	if (title)
		[cell setText:NSLocalizedString(title, @"section title")];
	
	if ([entry objectForKey:@"count"])
		cell.packageCount = [[entry objectForKey:@"count"] intValue];
	else
		cell.packageCount = 0;
	
	cell.odd = ([indexPath row] % 2);
	
	[cell setAccessoryType:UITableViewCellAccessoryDisclosureIndicator];
	
	return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	NSUInteger row = [indexPath row];
	NSDictionary* entry = [categoryCache objectAtIndex:row];
	
	NSString * title = [entry objectForKey:@"title"];
	
	// Prepare the view controller
	packagesTableViewController.category = title;
	packagesTableViewController.navigationItem.title = NSLocalizedString(title, @"section title");

	// Push it
	[self.navigationController pushViewController:packagesTableViewController animated:YES];
}

@end
