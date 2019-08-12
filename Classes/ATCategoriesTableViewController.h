//
//  ATCategoriesTableViewController.h
//  Installer
//
//  Created by Maksim Rogov on 11/07/08.
//  Copyright 2008 Nullriver, Inc.. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "ATSource.h"
#import "ATPackage.h"
#import "ATTableViewController.h"
#import "ATPackagesTableViewController.h"
#import "ATPackage.h"
#import "ATPackageCell.h"
#import "ATCategoriesCell.h"


@interface ATCategoriesTableViewController : ATTableViewController {
	IBOutlet ATPackagesTableViewController * packagesTableViewController;
	
	NSMutableArray* categoryCache;
}

- (void)_rebuildCache:(id)sender;
@end
