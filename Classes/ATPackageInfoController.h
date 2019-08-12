#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <UIKit/UIStringDrawing.h>

#import "ATViewController.h"
#import "ATIconView.h"
#import "ATPackageMoreInfoView.h"
#import "ATSourceInfoController.h"

#import "ATRatingView.h"

@interface ATPackageInfoController : ATViewController <UIActionSheetDelegate> {
	IBOutlet ATPackageMoreInfoView *moreInfoView;
    IBOutlet UILabel *packageDateLabel;
    IBOutlet UILabel *packageDescriptionLabel;
    IBOutlet UILabel *packageSizeLabel;
    IBOutlet UILabel *packageSourceLabel;
    IBOutlet UILabel *packageVersionLabel;
    IBOutlet UILabel *packageNameLabel;
    IBOutlet UILabel *packageEMailLabel;
    IBOutlet ATSourceInfoController *sourceInfoView;
    IBOutlet UIImageView *movingDownSeparator;
    IBOutlet UIButton *movingMailButton;
	IBOutlet UIButton *sourceInfoButton;
    IBOutlet UIButton *movingMoreInfoButton;
    IBOutlet UILabel *movingMoreInfoLabel;
    IBOutlet UIButton *movingSponsorButton;
    IBOutlet UILabel *movingSponsorLabel;
	
	IBOutlet UIView *movingBottomView;
	IBOutlet ATRatingView* ratingView;
	IBOutlet UIView *scrollerContentView;
	IBOutlet UIScrollView* scrollerView;
	
	ATPackage *package;
	ATIconView *iconView;

	UIBarButtonItem *installButton;
	UIBarButtonItem *uninstallButton;
	UIBarButtonItem *updateButton;
	
//	@private
//		CGRect			mOriginalViewSize;
}
- (IBAction)moreInfoButtonPressed:(id)sender;
- (IBAction)sourceInfoButtonPressed:(id)sender;
- (IBAction)mailButtonPressed:(id)sender;
- (IBAction)installButtonPressed:(id)sender;
- (IBAction)sponsorButtonPressed:(id)sender;

@property (retain, nonatomic) ATPackage *package;

@end
