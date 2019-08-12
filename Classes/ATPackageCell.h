//
//  ATPackageCell.h
//  Installer
//
//  Created by DigitalStealth on 17.07.08.
//  Copyright 2008 DIGITAL STEALTH DESIGN GROUP. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "ATPackageManager.h"
#import "ATInstaller.h"
#import "ATPackage.h"
#import "ATIconView.h"
#import "ATTableViewCell.h"


@interface ATPackageCell : ATTableViewCell {
	UILabel *packageNameView;
	UILabel *packageDescriptionView;
	UILabel *packageVersionView;
	ATIconView *iconView;
	bool isIndicatorShown;
	UIActivityIndicatorView *indicator;
	
	ATPackage* package;
	
	BOOL iconFetched;
}

@property (retain) ATPackage* package;

- (id)initWithFrame:(CGRect)frame reuseIdentifier:(NSString *)reuseIdentifier package:(ATPackage*)pack;
- (void) setShowIndicator:(bool)show;
- (void) _didEndHideIndicatorAnimation:(id)sender;
- (void)setPackage:(ATPackage*)package;
@end
