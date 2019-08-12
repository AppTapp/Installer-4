//
//  ATViewController.m
//  Installer
//
//  Created by Maksim Rogov on 22/06/08.
//  Copyright 2008 Nullriver, Inc.. All rights reserved.
//

#import "ATViewController.h"


@implementation ATViewController

- (id)initWithCoder:(NSCoder *)decoder {
	if(self = [super initWithCoder:decoder]) {
	}
	
	return self;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
	return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

- (void)didReceiveMemoryWarning {
	[super didReceiveMemoryWarning];
}

@end
