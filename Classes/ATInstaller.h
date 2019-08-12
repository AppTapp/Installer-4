//
//  ATInstaller.h
//  Installer
//
//  Created by Maksim Rogov on 25/04/08.
//  Copyright Nullriver, Inc. 2008. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "ATPackageManager.h"


@interface ATInstaller : NSObject <UIApplicationDelegate, UITabBarControllerDelegate> {
	IBOutlet UIWindow * window;

	UITabBarController * tabBarController;
	IBOutlet UIViewController * featuredViewController;
	IBOutlet UITableViewController * categoriesTableViewController;
	IBOutlet UITableViewController * sourcesTableViewController;
	IBOutlet UITableViewController * tasksTableViewController;
	IBOutlet UITableViewController * searchTableViewController;
	
	ATPackageManager * packageManager;
	UIActionSheet * progressSheet;
	UIProgressView * progressBar;
	
	BOOL canContinue;
	BOOL needsSuspend;
	BOOL shouldShowProgressSheet;
	int confirmedButton;
	
	BOOL	offeredUpdate;
	
	NSNotificationQueue* notificationQueue;
}

@property (nonatomic, retain) UIWindow * window;
@property (nonatomic, retain) UITabBarController * tabBarController;
@property (nonatomic, retain) ATPackageManager * packageManager;
@property (retain)  NSNotificationQueue* notificationQueue;

+ (ATInstaller *)sharedInstaller;

// Actions
- (IBAction)refreshAllSources:(id)sender;

@end
