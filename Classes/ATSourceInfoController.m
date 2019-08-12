//
//  ATSourceInfoController.m
//  Installer
//
//  Created by DigitalStealth on 20.07.08.
//  Copyright 2008 DIGITAL STEALTH DESIGN GROUP. All rights reserved.
//

#import "ATSourceInfoController.h"


@implementation ATSourceInfoController
- (IBAction)emailButtonPressed:(id)sender {
	NSURL* emailURL = [NSURL URLWithString:[NSString stringWithFormat:@"mailto:%@?subject=%@", source.contact, [@"Regarding Install source"  stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]]];
	
    [[UIApplication sharedApplication] openURL:emailURL]; 
}

- (IBAction)refreshSource:(id)sender {
	[[ATPackageManager sharedPackageManager] refreshSource:source];
}

- (IBAction)editingDidEnd:(UITextField*)sender
{
	NSString* newURL = sender.text;
	
	if (!self.source)
	{
		self.source = [[[ATSource alloc] init] autorelease];
	}
	
	NSURL* newLoc = [NSURL URLWithString:newURL];
	
	if (!newLoc || ![[newLoc scheme] isEqualToString:@"http"])
	{
		// abort edit
		sender.text = [self.source.location absoluteString];
		return;
	}
	
	if ([[newLoc absoluteString] isEqualToString:[self.source.location absoluteString]])
	{
		return;
	}
	
	ATSource* anotherSource = [[ATPackageManager sharedPackageManager].sources sourceWithLocation:[newLoc absoluteString]];
	
	if (anotherSource)
	{
		// This source is already there... Let's delete this one and push the controller out
		[self.source remove];
		[self.navigationController popViewControllerAnimated:YES];
		return;
	}
	
	self.source.location = newLoc;
	[self.source commit];
	
	[[ATPackageManager sharedPackageManager] refreshSource:source];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField              // called when 'return' key pressed. return NO to ignore.
{
	[textField endEditing:YES];
	
	return YES;
}

- (BOOL)textFieldShouldBeginEditing:(UITextField *)textField
{
	if ([[self.source.location absoluteString] isEqualToString:__DEFAULT_SOURCE_LOCATION__])
		return NO;

	return YES;			// but in the future, disallow for the default source
}

- (BOOL)textFieldShouldEndEditing:(UITextField *)textField          // return YES to allow editing to stop and to resign first responder status. NO to disallow the editing session to end
{
	return YES;
}

@synthesize source;

/*
 Implement loadView if you want to create a view hierarchy programmatically
- (void)loadView {
}
 */

- (void)viewDidLoad {
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(sourceRefreshed:) name:ATSourceUpdatedNotification object:nil];

	[super viewDidLoad];
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[super dealloc];
}

- (void)sourceRefreshed:(NSNotification*)notification
{
	//NSLog(@"Source info, refresh. Self entry id = %u, notification entry id = %u, obj = %@", self.source.entryID, ((ATSource*)[notification object]).entryID, [notification object]);
	
	//if (((ATSource*)[notification object]).entryID == self.source.entryID)
	if (self.source)
	{
		[self updateSource];
	}
}


- (void) viewWillAppear:(BOOL)animated
{
	[self updateSource];
	
	NSString *sourcePath = [self.source.location absoluteString];
	if(sourcePath == nil || [sourcePath length] == 0 || [sourcePath isEqualToString:@"http://"])
	{
		// begin editing
		[urlLabel becomeFirstResponder];
	}
	
	[super viewWillAppear:animated];
}

- (void)updateSource
{
	if (self.source.name && [self.source.name length])
		[sourceNameLabel setText:self.source.name];
	else
		[sourceNameLabel setText:NSLocalizedString(@"New Source", @"")];
	
	NSString *sourcePath = [self.source.location absoluteString];
	if(sourcePath == nil || [sourcePath length] == 0)
		sourcePath = @"http://";
	
	[urlLabel setText:sourcePath];
	
	[categoryLabel setText:self.source.category];
	
	if ([self.source.hasErrors boolValue])
	{
		[definitionLabel setText:NSLocalizedString(@"There were errors while trying to refresh this source. Please double-check the URL and try refreshing again.", @"")];
	}
	else
	{
		if (![self.source.description length])
			[definitionLabel setText:NSLocalizedString(@"Please input the valid source URL above to add the source.", @"")];
		else
			[definitionLabel setText:self.source.description];
	}
	
	if (self.source.icon)
	{
		[imageView setImage:self.source.icon];
	}
	else
	{
		BOOL isTrust = [self.source.isTrusted boolValue];
		if(isTrust)
			[imageView setImage:[UIImage imageNamed:@"ATSource_Trusted.png"]];
		else
			[imageView setImage:[UIImage imageNamed:@"ATSource.png"]];
	}
	
	if (self.source.contact)
	{
		NSString *contactStr = [NSString stringWithFormat:@"%@: %@", NSLocalizedString(@"Contact", @""), source.contact];
		[contactLabel setText:contactStr];
	}
	else
	{
		[contactLabel setText:@""];
	}
	
	CGRect rTemp = definitionLabel.frame;
	CGSize sz = [definitionLabel.text	sizeWithFont:definitionLabel.font 
				 constrainedToSize:CGSizeMake(rTemp.size.width, 150)
				 lineBreakMode:UILineBreakModeWordWrap];
	float diff = rTemp.size.height - sz.height - 20;
	
	rTemp.size.height = sz.height + 20;
	definitionLabel.frame = rTemp;
	
	CGRect rTemp2 = movingBottomSeparator.frame;
	rTemp2.origin.y -= diff;
	movingBottomSeparator.frame = rTemp2;
	
	rTemp2 = contactLabel.frame;
	rTemp2.origin.y -= diff;
	contactLabel.frame = rTemp2;
	
	rTemp2 = movingMailButton.frame;
	rTemp2.origin.y -= diff;
	movingMailButton.frame = rTemp2;
	
	/*
	 if (isTrust)
	 self.navigationController.navigationBar.tintColor = [UIColor colorWithRed:0 green:1.0 blue:0 alpha:0.5];
	 else if ([source.isUnsafe boolValue])
	 self.navigationController.navigationBar.tintColor = [UIColor colorWithRed:1.0 green:0 blue:0 alpha:0.5];
	 else
	 self.navigationController.navigationBar.tintColor = nil;
	 */	
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
	// Return YES for supported orientations
	return (interfaceOrientation == UIInterfaceOrientationPortrait);
}


- (void)didReceiveMemoryWarning {
	[super didReceiveMemoryWarning]; // Releases the view if it doesn't have a superview
	// Release anything that's not essential, such as cached data
}

@end
