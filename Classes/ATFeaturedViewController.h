//
//  ATFeaturedViewController.h
//  Installer
//
//  Created by Maksim Rogov on 25/04/08.
//  Copyright Nullriver, Inc. 2008. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "ATViewController.h"

@class ATPackage;
@class ATPackageInfoController;
@class ATPackageMoreInfoView;
@class ATSearchTableViewController;

@interface ATFeaturedViewController : ATViewController <UIWebViewDelegate>{
	IBOutlet UIWebView * webView;

    IBOutlet ATPackageInfoController *packageInfoController;
    IBOutlet ATPackageMoreInfoView *packageCustomInfoController;
	
	IBOutlet ATSearchTableViewController *searchTableController;
	
	IBOutlet UISegmentedControl* titleControl;

	ATPackage* moreInfoPackage;
}

@property (retain, nonatomic) ATPackage* moreInfoPackage;

- (IBAction)segmentedControlChanged:(UISegmentedControl*)sender;

- (void)showPackageInfo:(NSString*)packageID;

- (NSString*)renderAbout;

@end
