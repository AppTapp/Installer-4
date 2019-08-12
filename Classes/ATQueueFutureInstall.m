//
//  ATQueueFutureInstall.m
//  Installer
//
//  Created by Slava Karpenko on 21/08/2008.
//  Copyright 2008 RiP Dev. All rights reserved.
//

#import "ATQueueFutureInstall.h"
#import "ATPackageManager.h"
#import "ATPackage.h"
#import "ATPackages.h"
#import "ATPipelineManager.h"

@implementation ATQueueFutureInstall

@synthesize packageID;

- initWithPackageID:(NSString*)identifier;
{
	if (self = [super init])
	{
		self.packageID = identifier;
	}
	
	return self;
}

- (void)dealloc
{
	self.packageID = nil;
	[super dealloc];
}

#pragma mark -

- (NSString*)taskID
{
	return [NSString stringWithFormat:@"future-install:%@", self.packageID];
}

- (NSString*)taskDescription
{
	return NSLocalizedString(@"Queueing package install...", @"");
}

- (double)taskProgress
{
	return -1.;
}

- (NSArray*)taskDependencies
{
	return nil;
}

- (void)taskStart
{
	ATPackage* pack = [[ATPackageManager sharedPackageManager].packages packageWithIdentifier:self.packageID];
	if (pack)
	{
		NSError* err = nil;
		
		if (![pack install:&err])
		{
			[[ATPipelineManager sharedManager] taskDoneWithError:self error:err];
		}
		else
			[[ATPipelineManager sharedManager] taskDoneWithSuccess:self];
	}
	else
	{
		NSDictionary* userInfo = [NSDictionary dictionaryWithObjectsAndKeys: self.packageID, @"packageID",
																			[NSString stringWithFormat:NSLocalizedString(@"Cannot install package \"%@\" as it was not found. Sorry!", @""), self.packageID], NSLocalizedDescriptionKey,
								  nil];
		
		NSError* err = [NSError errorWithDomain:AppTappErrorDomain code:kATErrorPackageNotFound userInfo:userInfo];
		
		[[ATPipelineManager sharedManager] taskDoneWithError:self error:err];
	}
}

@end
