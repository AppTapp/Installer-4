//
//  ATTableViewController.m
//  Installer
//
//  Created by Maksim Rogov on 08/05/08.
//  Copyright 2008 Nullriver, Inc.. All rights reserved.
//

#import "ATTableViewController.h"


@implementation ATTableViewController

- (id)initWithCoder:(NSCoder *)decoder {
	if(self = [super initWithCoder:decoder]) {
		
		UITableView *table = self.tableView;
		table.rowHeight = 80.0;
		[table setBackgroundColor:[UIColor colorWithRed:.68 green:.68 blue:.69 alpha:1]];
		
		table.separatorStyle = UITableViewCellSeparatorStyleNone;
	}
	
	return self;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
	return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

- (void)didReceiveMemoryWarning {
	[super didReceiveMemoryWarning];
}

@end
