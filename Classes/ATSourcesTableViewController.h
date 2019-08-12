//
//  ATSourcesTableViewController.h
//  Installer
//
//  Created by Maksim Rogov on 08/05/08.
//  Copyright 2008 Nullriver, Inc.. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "ATSource.h"
#import "ATTableViewController.h"
#import "ATSourceInfoController.h"
#import "ATSourceTableViewCell.h"


@interface ATSourcesTableViewController : ATTableViewController <UITableViewDelegate> {
	    IBOutlet ATSourceInfoController *sourceInfoView;
	UIBarButtonItem *refreshAllButton;
	UIBarButtonItem *editButton;
	UIBarButtonItem *addButton;
	UIBarButtonItem *doneButton;
	bool editMode;

}

// Actions
- (IBAction) refreshAllSources:(id)sender;
- (IBAction) doEdit:(id)sender;
- (IBAction) addSource:(id)sender;

@end
