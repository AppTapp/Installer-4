//
//  ATIconView.h
//  Installer
//
//  Created by DigitalStealth on 19.07.08.
//  Copyright 2008 DIGITAL STEALTH DESIGN GROUP. All rights reserved.
//

#import <UIKit/UIKit.h>


@interface ATIconView : UIView {
	UIImage *icon;
	UIImage *iconMirror;
	bool isTrusted;
	bool isNew;
	
	BOOL hasErrors;
	BOOL drawShadow;
}

@property (assign, nonatomic) BOOL hasErrors;
@property (assign, nonatomic) BOOL drawShadow;

- (void) setIcon:(UIImage*) iconSource;
- (void) setTrusted:(bool)isT;
- (void) setNew:(bool) isN;

@end
