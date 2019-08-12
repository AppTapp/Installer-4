//
//  ATSearchTableViewController.h
//  Installer
//
//  Created by Slava Karpenko on 20/08/2008.
//  Copyright 2008 RiP Dev. All rights reserved.
//

#import <UIKit/UIKit.h>

@class ATPackageMoreInfoView;
@class ATPackageInfoController;
@class ATPackageCell;

@interface ATSearchTableViewController : UIViewController <UITableViewDelegate, UITableViewDataSource, UISearchBarDelegate> {
    IBOutlet ATPackageInfoController *packageInfoController;
    IBOutlet ATPackageMoreInfoView *packageCustomInfoController;
	IBOutlet UITableView * tableView;
	IBOutlet UISearchBar * searchBar;

	int fetchCellNumber;
	ATPackageCell *fetchCell;
}

- (void)setSearch:(NSString*)text;

@end
