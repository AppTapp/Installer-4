//
//  ATSourcesViewController.m
//  Installer
//
//  Created by Maksim Rogov on 08/05/08.
//  Copyright 2008 Nullriver, Inc.. All rights reserved.
//

#import "NSURL+AppTappExtensions.h"
#import "ATSourcesTableViewController.h"


@implementation ATSourcesTableViewController

- (void)viewDidLoad {
	[super viewDidLoad];
	editMode = NO;
	addButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd
																	 target:self 
																	 action:@selector(addSource:)];
	doneButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
															   target:self 
															   action:@selector(doEdit:)];
	editButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemEdit
																	 target:self 
																	 action:@selector(doEdit:)];
	[self.navigationItem setRightBarButtonItem:editButton];
	refreshAllButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh 
																	 target:self 
																	 action:@selector(refreshAllSources:)];
	[self.navigationItem setLeftBarButtonItem:refreshAllButton];
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(sourceRefreshed:) name:ATSourceUpdatedNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(iconChanged:) name:ATSourceInfoIconChangedNotification object:nil];
}

#pragma mark -
#pragma mark Actions

- (void)sourceRefreshed:(NSNotification*)notification
{
	[self.tableView reloadData];
}

- (void)iconChanged:(NSNotification*)notification
{
	ATSource* source = (ATSource*)[notification object];
	NSArray* visibleCells = [self.tableView visibleCells];
	
	for (ATSourceTableViewCell* ac in visibleCells)
	{
		ATSource* s = ac.source;
		
		if (s.entryID == source.entryID)
		{
			ac.source = source;	// update it!
			
			[self.tableView setNeedsDisplay];
		}
	}
}

- (IBAction)refreshAllSources:(id)sender {
	[[ATInstaller sharedInstaller] refreshAllSources:self];
}

- (IBAction)doEdit:(id)sender
{
	if(!editMode)
	{
		[self.navigationItem setRightBarButtonItem:doneButton];
		[self.navigationItem setLeftBarButtonItem:addButton];
		editButton.style = UIBarButtonSystemItemDone;
		editMode = YES;
		[self.tableView setEditing:YES animated:YES];
	}
	else
	{
		[self.navigationItem setRightBarButtonItem:editButton];
		[self.navigationItem setLeftBarButtonItem:refreshAllButton];
		editButton.style = UIBarButtonSystemItemEdit;
		editMode = NO;
		[self.tableView setEditing:NO animated:YES];
	}
}

- (IBAction) addSource:(id)sender
{
	ATSource* newSource = [[[ATSource alloc] init] autorelease];
	
	sourceInfoView.source = newSource;
	
	[self.navigationController pushViewController:sourceInfoView animated:YES];
}


#pragma mark -
#pragma mark UITableView Delegate/DataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return 1;
}
	
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	return [ATPackageManager sharedPackageManager].sources.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	ATSourceTableViewCell * cell = (ATSourceTableViewCell*)[tableView dequeueReusableCellWithIdentifier:@"cell"];
	
	NSInteger row = [indexPath row];
	
	ATSource * source = [[ATPackageManager sharedPackageManager].sources sourceAtIndex:row];
	
	if(cell == nil) {
		cell = [[[ATSourceTableViewCell alloc] initWithFrame:CGRectZero reuseIdentifier:@"cell" source:source] autorelease];
	}
	else
		[cell setSource:source];
	
	[cell setAccessoryType:UITableViewCellAccessoryDisclosureIndicator];
	
	cell.odd = (row % 2);
	
	return cell;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
	int row = [indexPath row];

	if([[[ATPackageManager sharedPackageManager].sources sourceAtIndex:row].location isEqualToURL:[NSURL URLWithString:__DEFAULT_SOURCE_LOCATION__]]) return NO;
	else return YES;
}

- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath {
	return UITableViewCellEditingStyleDelete;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
	NSUInteger row = [indexPath row];
	
	ATSource * source = [[ATPackageManager sharedPackageManager].sources sourceAtIndex:row];

	[source remove];
	[self.tableView reloadData];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	NSUInteger row = [indexPath row];

	ATSource * source = [[ATPackageManager sharedPackageManager].sources sourceAtIndex:row];
	sourceInfoView.source = source;
	
	[self.navigationController pushViewController:sourceInfoView animated:YES];
}

@end
