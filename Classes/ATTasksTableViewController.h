//
//  ATTasksTableViewController.h
//  Installer
//
//  Created by Maksim Rogov on 12/07/08.
//  Copyright 2008 Nullriver, Inc.. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "ATTableViewController.h"
#import "ATTaskTableViewCell.h"


@interface ATTasksTableViewController : ATTableViewController {
	NSMutableArray*			tasks;
}

@property (retain) NSMutableArray* tasks;

- (void)pipelineManagerNotification:(NSNotification*)notification;
@end
