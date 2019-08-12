//
//  ATPackageUninstallTask.m
//  Installer
//
//  Created by Slava Karpenko on 7/12/08.
//  Copyright 2008 RiP Dev. All rights reserved.
//

#import "ATPackageUninstallTask.h"
#import "ATPackage.h"
#import "ATPipelineManager.h"
#import "NSURL+AppTappExtensions.h"
#import "ATURLDownload.h"
#import "ATScript.h"
#import "ATPackageManager.h"

@implementation ATPackageUninstallTask

@synthesize package;
@synthesize script;
@synthesize status;
@synthesize progress;

- initWithPackage:(ATPackage*)pack
{
	if (self = [super init])
	{
		self.package = pack;
		self.status = @"Waiting...";
		self.progress = [NSNumber numberWithInt:-1];
	}
	
	return self;
}

- (void)dealloc
{
	self.status = nil;
	self.progress = nil;
	self.script = nil;
	self.package = nil;
	
	[super dealloc];
}

#pragma mark -
#pragma mark ATSource Protocol

- (NSString*)taskID
{
	return self.package.identifier;
}

- (NSString*)taskDescription
{
	return self.status;
}

- (double)taskProgress
{
	return [self.progress doubleValue];
}

- (NSArray*)taskDependencies
{
	return nil;		// Uninstall tasks have no dependencies
}

- (void)taskStart
{
	Log(@"ATPackageUninstallTask: uninstalling package %@", self.package.identifier);
	
	if (!self.script)
	{
		self.script = [[[ATScript alloc] initWithDelegate:self] autorelease];
		self.script.package = self.package;
	}
	
	NSArray* preflight = package.preflightScript;
	if (preflight)
	{
		Log(@"ATPackageUninstallTask: preflight = %@", preflight);

		NSError* error = nil;
		if (![self.script runScript:preflight withError:&error])
		{
			NSDictionary* userInfo = [NSDictionary dictionaryWithObjectsAndKeys:		self.package, @"package",
																						self, @"task",
																						preflight, @"script",
																						nil];
			
			
			error = [NSError errorWithDomain:AppTappErrorDomain code:kATErrorScriptError userInfo:userInfo];

			[[ATPipelineManager sharedManager] taskDoneWithError:self error:error];
			return;
		}
	}
		
	NSArray* uninstall = package.uninstallScript;
	
	Log(@"ATPackageUninstallTask: uninstall = %@", uninstall);
	if (uninstall)
	{
		NSError* error = nil;
		if (![self.script runScript:uninstall withError:&error])
		{
			NSDictionary* userInfo = [NSDictionary dictionaryWithObjectsAndKeys:		self.package, @"package",
																						self, @"task",
																						uninstall, @"script",
																						nil];
			
			
			error = [NSError errorWithDomain:AppTappErrorDomain code:kATErrorScriptError userInfo:userInfo];

			[[ATPipelineManager sharedManager] taskDoneWithError:self error:error];
			return;
		}
	}
		
	NSArray* postflight = package.postflightScript;
	if (postflight)
	{
		Log(@"ATPackageUninstallTask: postflight = %@", postflight);

		NSError* error = nil;
		if (![self.script runScript:postflight withError:&error])
		{
			NSDictionary* userInfo = [NSDictionary dictionaryWithObjectsAndKeys:		self.package, @"package",
																						self, @"task",
																						postflight, @"script",
																						nil];
			
			
			error = [NSError errorWithDomain:AppTappErrorDomain code:kATErrorScriptError userInfo:userInfo];

			[[ATPipelineManager sharedManager] taskDoneWithError:self error:error];
			return;
		}
	}

	// Record package as installed
	self.package.isInstalled = NO;
	[self.package commit];
			
	[ATPackageManager sharedPackageManager].springboardNeedsRefresh = YES;
	[self.package pingForAction:@"uninstall"];
	
	[[NSNotificationCenter defaultCenter] performSelectorOnMainThread:@selector(postNotification:) withObject:[NSNotification notificationWithName:ATSourceUpdatedNotification object:nil userInfo:nil] waitUntilDone:NO];
	[[ATPackageManager sharedPackageManager] updateApplicationBadge];
	
	if (!self.package.source)			// if this package has no sources assigned, also remove it from the database
		[self.package remove];
	
	[[ATPipelineManager sharedManager] taskDoneWithSuccess:self];
}

#pragma mark -
#pragma mark ATScript Delegate

// Mandatory
- (NSString*)packageFileNameForScript:(ATScript*)script
{
	return nil;
}

- (void)scriptIssueNotice:(ATScript*)sc notice:(NSString*)notice
{
	[[ATPackageManager sharedPackageManager] scriptIssueNotice:sc notice:notice];
}

- (void)scriptIssueError:(ATScript*)sc error:(NSString*)error
{
	[[ATPackageManager sharedPackageManager] scriptIssueError:sc error:error];
}

- (void)scriptIssueConfirmation:(ATScript*)sc arguments:(NSArray*)args
{
	[[ATPackageManager sharedPackageManager] scriptIssueConfirmation:sc arguments:args];
}

- (NSNumber*)scriptCanContinue:(ATScript*)sc
{
	return [[ATPackageManager sharedPackageManager] scriptCanContinue:sc];
}

- (NSNumber*)scriptConfirmationButton:(ATScript*)sc
{
	return [[ATPackageManager sharedPackageManager] scriptConfirmationButton:sc];
}

- (void)script:(ATScript*)script addSource:(NSString*)url
{
	[[ATPackageManager sharedPackageManager].sources addSourceWithLocation:url];
}

- (void)script:(ATScript*)script removeSource:(NSString*)url
{
	[[ATPackageManager sharedPackageManager].sources removeSourceWithLocation:url];
}

- (void)scriptRestartSpringBoard:(ATScript*)script
{
	[ATPackageManager sharedPackageManager].springboardNeedsHardRefresh = YES;
}

- (NSNumber*)scriptIsPackageInstalled:(NSString*)packageID
{
	return [NSNumber numberWithBool:[[ATPackageManager sharedPackageManager].packages packageIsInstalled:packageID]];
}

// Optional
- (void)scriptDidChangeProgress:(ATScript*)script progress:(NSNumber*)pr
{
	self.progress = progress;
	[[ATPipelineManager sharedManager] taskProgressChanged:self];
}

- (void)scriptDidChangeStatus:(ATScript*)script status:(NSString*)st
{
	self.status = status;
	[[ATPipelineManager sharedManager] taskStatusChanged:self];
}

@end
