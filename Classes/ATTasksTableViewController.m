#import "ATTasksTableViewController.h"

@implementation ATTasksTableViewController

@synthesize tasks;

- (id)initWithCoder:(NSCoder *)decoder {
	if(self = [super initWithCoder:decoder]) {

		self.tasks = [NSMutableArray arrayWithCapacity:0];

		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(pipelineManagerNotification:) name:ATPipelineTaskQueuedNotification object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(pipelineManagerNotification:) name:ATPipelineTaskFinishedNotification object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(pipelineManagerNotification:) name:ATPipelineTaskProgressNotification object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(pipelineManagerNotification:) name:ATPipelineTaskStatusNotification object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(pipelineManagerNotification:) name:ATPipelineTaskChangedNotification object:nil];
	}
	return self;
}

- (void)viewDidLoad
{
	[super viewDidLoad];
	
	[self.navigationItem setRightBarButtonItem:self.editButtonItem];
	
	[self.tableView reloadData];
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
	self.tasks = nil;
	
	[super dealloc];
}

- (void)viewWillAppear:(BOOL)animated
{
	[self.tableView reloadData];
}

#pragma mark -
#pragma mark UITableView Delegate/DataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
	return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	NSInteger count = [self.tasks count];

	return count + 1;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
	if (indexPath.row >= [self.tasks count])
		return 1.;
		
	return 80.;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	if (indexPath.row >= [self.tasks count])
	{
		UITableViewCell* nilCell = [tableView dequeueReusableCellWithIdentifier:@"nil"];
		
		if (nilCell)
			return nilCell;
			
		return [[[UITableViewCell alloc] initWithFrame:CGRectZero reuseIdentifier:@"nil"] autorelease];
	}

	UITableViewCell * cell = [tableView dequeueReusableCellWithIdentifier:@"cell"];
	
	NSInteger row = [indexPath row];
	
	if (cell == nil)
	{
		cell = [[[ATTaskTableViewCell alloc] initWithFrame:CGRectZero reuseIdentifier:@"cell"] autorelease];
	}
	
	// here is initializing of cell
	ATTaskTableViewCell *taskCell = (ATTaskTableViewCell *)cell;
	id<ATTask> task = [self.tasks objectAtIndex:row];
	ATPipeline* pipe = [[ATPipelineManager sharedManager] findPipelineForTask:task];
	NSString* pipelineID = [[ATPipelineManager sharedManager] piplineIDForTask:task];
	NSString* title = NSLocalizedString(@"Processing", @"");
	ATTaskTableCellTypes cellType = ATTaskTableCellInstall;
	
	if ([pipelineID isEqualToString:ATPipelineSourceRefresh])
	{
		NSString* sourceName = @"";
		
		if ([(NSObject*)task respondsToSelector:@selector(taskLocalizedObjectName)])
			sourceName = [task taskLocalizedObjectName];
		title = [NSString stringWithFormat:@"%@ %@", NSLocalizedString(@"Refreshing", @""), sourceName];
		cellType = ATTaskTableCellRefresh;
	}
	else if ([pipelineID isEqualToString:ATPipelineSearch])
	{
		title = NSLocalizedString(@"Searching", @"");
		cellType = ATTaskTableCellDownload;
	}
	
	[taskCell setTitle:title];
	[taskCell setDescription:[task taskDescription]];
	[taskCell setType:cellType];
	[taskCell setStatus:(pipe.currentTask == task) ? ATTaskTableCellStatusActive : ATTaskTableCellStatusIdle];
	[taskCell setShowProgress:([task taskProgress] >= 0)];
	[taskCell setProgress:[task taskProgress]];
	
	taskCell.odd = (row % 2);
	
	return cell;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
	if (indexPath.row >= [self.tasks count])
		return NO;
		
	id<NSObject,ATTask> task = [self.tasks objectAtIndex:indexPath.row];
	
	if ([task respondsToSelector:@selector(taskCanCancel)] &&
		[task respondsToSelector:@selector(taskCancel)])
			return YES;
			
	return NO;
}

- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath
{
	return NO;
}

- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath
{
	return UITableViewCellEditingStyleDelete;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
	id<NSObject,ATTask> task = [self.tasks objectAtIndex:indexPath.row];
	
	if ([task respondsToSelector:@selector(taskCanCancel)] &&
		[task respondsToSelector:@selector(taskCancel)] &&
		[task taskCanCancel])
	{
			[task taskCancel];
			[self.tasks removeObject:task];
			[tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationFade];
	}
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
//	NSUInteger row = [indexPath row];
}

#pragma mark -

- (void)pipelineManagerNotification:(NSNotification*)notification
{	
	NSString* name = [notification name];
	id task = [notification object];
	NSString* pipelineName = [[notification userInfo] objectForKey:ATPipelineUserInfoPipelineID];
	
	if ([pipelineName isEqualToString:ATPipelineErrors] || [pipelineName isEqualToString:ATPipelineMisc] || [pipelineName isEqualToString:ATPipelineSearch] || ![pipelineName length])
	{
		//NSLog(@"Tasks manager: ignoring task %@ for pipeline %@", task, pipelineName);
		return;
	}
	
	if ([name isEqualToString:ATPipelineTaskQueuedNotification])
	{
		[self.tasks addObject:task];
		
		NSArray* arr = [NSArray arrayWithObject:[NSIndexPath indexPathForRow:[self.tasks count]-1 inSection:0]];
		[self.tableView insertRowsAtIndexPaths:arr withRowAnimation:UITableViewRowAnimationLeft];
	}
	else if ([name isEqualToString:ATPipelineTaskFinishedNotification])
	{
		NSUInteger idx = [self.tasks indexOfObject:task];
		if (idx != NSNotFound)
		{
			[self.tasks removeObjectAtIndex:idx];
			[self.tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:[NSIndexPath indexPathForRow:idx inSection:0]] withRowAnimation:UITableViewRowAnimationRight];
		}
	} 
	else if (	[name isEqualToString:ATPipelineTaskProgressNotification] ||
				[name isEqualToString:ATPipelineTaskChangedNotification] ||
				[name isEqualToString:ATPipelineTaskStatusNotification] )
	{
		NSUInteger idx = [self.tasks indexOfObject:task];
		if (idx != NSNotFound)
		{
			ATTaskTableViewCell* cell = (ATTaskTableViewCell*)[self.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:idx inSection:0]];
			if (cell)
			{
				[cell setDescription:[task taskDescription]];
				if ([name isEqualToString:ATPipelineTaskChangedNotification])
					[cell setStatus:[[notification userInfo] objectForKey:@"isActiveTask"] ? ATTaskTableCellStatusActive : ATTaskTableCellStatusIdle];
				[cell setShowProgress:([task taskProgress] >= .0)];
				[cell setProgress:[task taskProgress]];
				
				[cell setNeedsDisplay];
			}
			
			// update odd states
			NSArray* visibleCells = [self.tableView visibleCells];
			for (ATTaskTableViewCell* cell in visibleCells)
			{
				NSIndexPath* p = [self.tableView indexPathForCell:cell];
				
				if ([cell isKindOfClass:[ATTaskTableViewCell class]])
				{
					cell.odd = (p.row % 2);
					[cell setNeedsDisplay];
				}
			}
		}
	}
	
	if ([self.tasks count])
		self.tabBarItem.badgeValue = [NSString stringWithFormat:@"%u", [self.tasks count]];
	else
		self.tabBarItem.badgeValue = nil;
}

@end
