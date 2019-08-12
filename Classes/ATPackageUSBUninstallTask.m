//
//  ATPackageUSBUninstallTask.m
//  Installer
//
//  Created by Slava Karpenko on 7/12/08.
//  Copyright 2008 RiP Dev. All rights reserved.
//

#import "ATPackageUSBUninstallTask.h"
#import "ATPackage.h"
#import "ATPipelineManager.h"
#import "NSURL+AppTappExtensions.h"
#import "ATURLDownload.h"
#import "ATScript.h"
#import "ATPackageManager.h"

#ifdef INSTALLER_APP
    #import "IAPhoneManager.h"
    #import "IAErrorProcessor.h"
#endif // INSTALLER_APP

@implementation ATPackageUSBUninstallTask

@synthesize package;
@synthesize status;
@synthesize progress;

- (id)initWithPackage:(ATPackage*)pack
{
	if (self = [super init])
	{
		self.package = pack;
		self.status = @"Waiting...";
		self.progress = [NSNumber numberWithInt:-1];

#ifdef INSTALLER_APP
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(uninstallPackageProcessDidFinish:) name:IAPhoneUninstallPackageProcessDidFinishNotificationName object:pack];
#endif // INSTALLER_APP
	}

	return self;
}

- (void)dealloc
{
#ifdef INSTALLER_APP
    [[NSNotificationCenter defaultCenter] removeObserver:self name:IAPhoneUninstallPackageProcessDidFinishNotificationName object:self.package];
#endif // INSTALLER_APP

	self.status = nil;
	self.progress = nil;
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
#ifdef INSTALLER_APP
    self.status = [NSString stringWithFormat:NSLocalizedString(@"Uninstalling %@", @""), self.package.name];
    [[ATPipelineManager sharedManager] taskStatusChanged:self];

    [[IAPhoneManager sharedPhoneManager] uninstallPackage:self.package];
#endif // INSTALLER_APP
}

#pragma mark -

- (void)uninstallPackageProcessDidFinish:(NSNotification*)notification
{
#ifdef INSTALLER_APP
    BOOL uninstallResult = [[[notification userInfo] objectForKey:IAPhonePackageProcessResultKey] boolValue];
    NSError* error = [[notification userInfo] objectForKey:IAPhonePackageProcessErrorKey];

    if (uninstallResult || (!uninstallResult && [[[error userInfo] objectForKey:IASubErrorKey] integerValue] != errUninstallDependsError))
    {
        if (uninstallResult)
        {
            if (self.package.synchronizeStatus > 0)
                self.package.synchronizeStatus = ATPackageSynchronized;
        }

        // Record package as installed
        self.package.isInstalled = NO;
        [self.package commit];

        if (!self.package.source) // if this package has no sources assigned, also remove it from the database
            [self.package remove];

        NSString* filePath = [__DOWNLOADS_PATH__ stringByAppendingPathComponent:package.identifier];
        [[NSFileManager defaultManager] removeItemAtPath:filePath error:nil];

        [ATPackageManager sharedPackageManager].springboardNeedsRefresh = YES;

        [self.package performSelectorOnMainThread:@selector(pingForAction:) withObject:@"uninstall" waitUntilDone:NO modes:[NSArray arrayWithObjects:NSDefaultRunLoopMode, NSModalPanelRunLoopMode, NSEventTrackingRunLoopMode, nil]];
        [[NSNotificationCenter defaultCenter] performSelectorOnMainThread:@selector(postNotification:) withObject:[NSNotification notificationWithName:ATSourceUpdatedNotification object:self.package.source userInfo:nil] waitUntilDone:NO modes:[NSArray arrayWithObjects:NSDefaultRunLoopMode, NSModalPanelRunLoopMode, NSEventTrackingRunLoopMode, nil]];

        [[ATPackageManager sharedPackageManager] updateApplicationBadge];
    }

    if (uninstallResult)
        [[ATPipelineManager sharedManager] taskDoneWithSuccess:self];
    else
        [[ATPipelineManager sharedManager] taskDoneWithError:self error:error];
#endif // INSTALLER_APP
}

@end
