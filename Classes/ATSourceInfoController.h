//
//  ATSourceInfoController.h
//  Installer
//
//  Created by DigitalStealth on 20.07.08.
//  Copyright 2008 DIGITAL STEALTH DESIGN GROUP. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "ATViewController.h"
#import "ATInstaller.h"


@interface ATSourceInfoController : ATViewController {
    IBOutlet UILabel *categoryLabel;
    IBOutlet UILabel *contactLabel;
    IBOutlet UILabel *definitionLabel;
    IBOutlet UIImageView *imageView;
    IBOutlet UILabel *sourceNameLabel;
    IBOutlet UITextField *urlLabel;
    IBOutlet UIImageView *movingBottomSeparator;
    IBOutlet UIButton *movingMailButton;

	ATSource *source;

}
- (IBAction)emailButtonPressed:(id)sender;
- (IBAction)refreshSource:(id)sender;
- (IBAction)editingDidEnd:(UITextField*)sender;
- (void)updateSource;

@property (retain, nonatomic) ATSource *source;

@end
