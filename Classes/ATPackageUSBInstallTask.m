//
//  ATPackageUSBInstallTask.m
//  Installer
//
//  Created by Slava Karpenko on 7/12/08.
//  Copyright 2008 RiP Dev. All rights reserved.
//

#import "ATPackageUSBInstallTask.h"
#import "ATPackage.h"
#import "ATPipelineManager.h"
#import "NSURL+AppTappExtensions.h"
#import "ATURLDownload.h"
#import "ATScript.h"
#import "ATPackageManager.h"
#import "ATDatabase.h"

#ifdef INSTALLER_APP
    #import "IAPhoneManager.h"
#endif // INSTALLER_APP

NSString* const ATPackageSourcesCategoryName = @"Sources";
NSString* const ATTelesphoreoUserAgent = @"Telesphoreo APT-HTTP/1.0.534";

@implementation ATPackageUSBInstallTask

@synthesize package;
@synthesize download;
@synthesize tempFileName;
@synthesize script;
@synthesize status;
@synthesize progress;
@synthesize downloadBytes;
@synthesize canCancel;

- (id)initWithPackage:(ATPackage*)pack
{
	if (self = [super init])
	{
		self.package = pack;
		self.status = @"Waiting...";
		self.downloadBytes = 0;
		self.progress = [NSNumber numberWithInt:-1];

#ifdef INSTALLER_APP
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(installPackageProcessDidFinish:) name:IAPhoneInstallPackageProcessDidFinishNotificationName object:pack];
#endif // INSTALLER_APP
	}

	return self;
}

- (void)dealloc
{
#ifdef INSTALLER_APP
    [[NSNotificationCenter defaultCenter] removeObserver:self name:IAPhoneInstallPackageProcessDidFinishNotificationName object:self.package];
#endif // INSTALLER_APP

	[self.download cancel];
    if (download.delegate == self)
        download.delegate = nil;

	self.status = nil;
	self.progress = nil;
	self.package = nil;
	self.download = nil;
	self.tempFileName = nil;
	self.script = nil;

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
	NSMutableArray* deps = [NSMutableArray arrayWithCapacity:0];
	
	for (NSString* depID in self.package.dependencies)
	{
		if (![[ATPackageManager sharedPackageManager].packages packageIsInstalled:depID])
			[deps addObject:depID];
	}
	
	return deps;
}

- (void)taskStart
{
    NSString* userAgent = nil;

#ifdef INSTALLER_APP
	NSURL* sourceURL = self.package.location;

    if (self.package.source != nil)
    {
        if (self.package.isCydiaPackage)
            userAgent = ATTelesphoreoUserAgent;
        else
            sourceURL = [sourceURL URLWithInstallerParameters];
    }
#else
	NSURL* sourceURL = [self.package.location URLWithInstallerParameters];
#endif // INSTALLER_APP

    NSString* downloadPath = [__DOWNLOADS_PATH__ stringByAppendingPathComponent:self.package.identifier];

	self.status = [NSString stringWithFormat:NSLocalizedString(@"Downloading %@", @""), self.package.name];
	[[ATPipelineManager sharedManager] taskStatusChanged:self];

    if ([[NSFileManager defaultManager] fileExistsAtPath:downloadPath] || sourceURL == nil)
    {
        self.tempFileName = downloadPath;

        [self downloadDidFinish:nil];
    }
    else
        self.download = [[[ATURLDownload alloc] initWithRequest:[NSURLRequest requestWithURL:sourceURL] delegate:self resumeable:YES userAgent:userAgent] autorelease];
}

- (BOOL)taskCanCancel
{
    return self.canCancel;
}

- (void)taskCancel
{
	if (!self.canCancel)
		return;

	[self.download cancelDownload];
}

#pragma mark -
#pragma mark ATURLDownload delegate

- (void)download:(ATURLDownload*)download didReceiveDataOfLength:(NSUInteger)length
{
	self.downloadBytes += length;

	double taskProgress = 0.0f;

    if (self.package.size != nil && [self.package.size doubleValue] > 0.0)
    {
        taskProgress = ((double)downloadBytes / [self.package.size doubleValue]);
        self.progress = [NSNumber numberWithDouble:taskProgress];
    }

	[[ATPipelineManager sharedManager] taskProgressChanged:self];
}

- (void)download:(ATURLDownload*)dl didCreateDestination:(NSString*)path
{
    self.canCancel = YES;

	self.tempFileName = path;
	self.downloadBytes = [[[NSFileManager defaultManager] fileAttributesAtPath:path traverseLink:YES] fileSize];
}

- (void)downloadDidFinish:(ATURLDownload*)dl
{
	self.canCancel = NO;

    BOOL needJailbreak = NO;

    if (dl != nil)
    {
        self.progress = [NSNumber numberWithDouble:-1.];
        [[ATPipelineManager sharedManager] taskProgressChanged:self];
        
        self.status = [NSString stringWithFormat:NSLocalizedString(@"Checking %@", @""), self.package.name];
        [[ATPipelineManager sharedManager] taskStatusChanged:self];
        
        // Step 1. Check the downloaded file.
        NSString* fileHash = [[NSFileManager defaultManager] fileHashAtPath:self.tempFileName];
        if (self.package.hash && ![fileHash isEqualToString:self.package.hash])
        {
            // Hash does not match
            NSDictionary* userInfo = [NSDictionary dictionaryWithObjectsAndKeys:		self.package, @"package",
                                                                                        self, @"task",
                                                                                        nil];
                                                                                        
            NSError* error = [NSError errorWithDomain:AppTappErrorDomain code:kATErrorPackageHashInvalid userInfo:userInfo];
            
            [[ATPipelineManager sharedManager] taskDoneWithError:self error:error];
            return;
        }
        
        // Step 2. Check the file size.
        unsigned long long fileSize = [[[NSFileManager defaultManager] fileAttributesAtPath:self.tempFileName traverseLink:YES] fileSize];
        if (!self.package.size || [self.package.size unsignedLongLongValue] != fileSize)
        {
            // Hash does not match
            NSDictionary* userInfo = [NSDictionary dictionaryWithObjectsAndKeys:		self.package, @"package",
                                                                                        self, @"task",
                                                                                        nil];
                                                                                        
            NSError* error = [NSError errorWithDomain:AppTappErrorDomain code:kATErrorPackageFileSizeInvalid userInfo:userInfo];
            
            [[ATPipelineManager sharedManager] taskDoneWithError:self error:error];
            return;
        }
    }

    while (YES)
    {
        self.status = [NSString stringWithFormat:NSLocalizedString(@"Preparing %@", @""), self.package.name];
        [[ATPipelineManager sharedManager] taskStatusChanged:self];

        // Step 3. Extract the script and assign it to ATScript.
        if (!self.script)
        {
            self.script = [[[ATScript alloc] initWithDelegate:self] autorelease];
            self.script.package = self.package;
        }

        NSString* tempInfoPath = [[NSFileManager defaultManager] tempFilePath];

        if ([self.script.unpacker copyCompressedPath:@"Install.plist" toFileSystemPath:tempInfoPath])
        {
            NSDictionary* infoPlist = [NSDictionary dictionaryWithContentsOfFile:tempInfoPath];
            if (infoPlist != nil)
            {
                // Check for jailbroken device.
                if ([infoPlist objectForKey:@"jailbreak-required"] && [[infoPlist objectForKey:@"jailbreak-required"] boolValue])
                    needJailbreak = YES;

                if (![self.package.category isEqualToString:ATPackageSourcesCategoryName])
                    break;

                NSDictionary* scripts = [infoPlist objectForKey:@"scripts"];

                if (scripts != nil)
                {
                    NSArray* preflight = [scripts objectForKey:@"preflight"];
                    NSError* error = nil;

                    if (preflight != nil)
                    {
                        self.status = [NSString stringWithFormat:NSLocalizedString(@"Pre-flight for %@", @""), self.package.name];
                        [[ATPipelineManager sharedManager] taskStatusChanged:self];

                        if (![self.script runScript:preflight withError:&error])
                        {
                            [[ATPipelineManager sharedManager] taskDoneWithError:self error:error];
                            break;
                        }
                    }

                    BOOL isInstalled = [[ATPackageManager sharedPackageManager].packages packageIsInstalled:self.package.identifier];
                    NSArray* install = nil;

                    if (isInstalled)
                        install = [scripts objectForKey:@"update"];

                    if (install == nil)
                        install = [scripts objectForKey:@"install"];

                    if (install != nil)
                    {
                        self.status = [NSString stringWithFormat:NSLocalizedString(@"Installing %@", @""), self.package.name];
                        [[ATPipelineManager sharedManager] taskStatusChanged:self];

                        if (![self.script runScript:install withError:&error])
                        {
                            [[ATPipelineManager sharedManager] taskDoneWithError:self error:error];
                            break;
                        }
                    }

                    NSArray* postflight = [scripts objectForKey:@"postflight"];

                    if (postflight != nil)
                    {
                        self.status = [NSString stringWithFormat:NSLocalizedString(@"Post-flight for %@", @""), self.package.name];
                        [[ATPipelineManager sharedManager] taskStatusChanged:self];

                        if (![self.script runScript:postflight withError:&error])
                        {
                            [[ATPipelineManager sharedManager] taskDoneWithError:self error:error];
                            break;
                        }
                    }

                    NSArray* uninstall = [scripts objectForKey:@"uninstall"];
                    if (uninstall != nil)
                    {
                        NSMutableArray* uninstallScript = [NSMutableArray arrayWithArray:uninstall];

                        [self embedLuaObjectsInto:uninstallScript];

                        self.package.uninstallScript = uninstallScript;
                    }

                    if (preflight != nil)
                    {
                        NSMutableArray* preflightScript = [NSMutableArray arrayWithArray:preflight];

                        [self embedLuaObjectsInto:preflightScript];

                        self.package.preflightScript = preflightScript;				
                    }

                    if (postflight != nil)
                    {
                        NSMutableArray* postflightScript = [NSMutableArray arrayWithArray:postflight];

                        [self embedLuaObjectsInto:postflightScript];

                        self.package.postflightScript = postflightScript;				
                    }
                }
            }

            [[NSFileManager defaultManager] removeItemAtPath:tempInfoPath error:nil];
        }

        break;
    }

    if (dl != nil)
    {
        NSString* newPath = [[self.tempFileName stringByDeletingLastPathComponent] stringByAppendingPathComponent:self.package.identifier];
        [[NSFileManager defaultManager] moveItemAtPath:self.tempFileName toPath:newPath error:nil];
    }

#ifdef INSTALLER_APP
    if (self.package.location == nil)
    {
        NSError* error = [NSError errorWithDomain:AppTappErrorDomain code:kATErrorPackageInvalidLocation userInfo:[NSDictionary dictionaryWithObjectsAndKeys:self.package, @"package", self, @"task", nil]];

        [[ATPipelineManager sharedManager] taskDoneWithError:self error:error];
    }
    else
    {
        self.status = [NSString stringWithFormat:NSLocalizedString(@"Installing %@", @""), self.package.name];
        [[ATPipelineManager sharedManager] taskStatusChanged:self];

        [[IAPhoneManager sharedPhoneManager] installPackage:self.package needJailbreak:needJailbreak];
    }
#endif // INSTALLER_APP
}

- (void)download:(ATURLDownload*)dl didFailWithError:(NSError*)error
{
	Log(@"ATPackageUSBInstallTask: download did fail (%@) = %@!", self.tempFileName, error);
	
	self.canCancel = NO;

	[[ATPipelineManager sharedManager] taskDoneWithError:self error:error];
}

#pragma mark -
#pragma mark ATScript Delegate

// Mandatory
- (NSString*)packageFileNameForScript:(ATScript*)script
{
    return self.tempFileName;
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

- (void)script:(ATScript*)sc addSource:(NSString*)url
{
    [[ATPackageManager sharedPackageManager].sources addSourceWithLocation:url];
}

- (void)script:(ATScript*)sc removeSource:(NSString*)url
{
    [[ATPackageManager sharedPackageManager].sources removeSourceWithLocation:url];
}

- (void)scriptRestartSpringBoard:(ATScript*)sc
{
    [ATPackageManager sharedPackageManager].springboardNeedsRefresh = YES;
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

#pragma mark -

- (void)installPackageProcessDidFinish:(NSNotification*)notification
{
#ifdef INSTALLER_APP
    BOOL installResult = [[[notification userInfo] objectForKey:IAPhonePackageProcessResultKey] boolValue];

    if (installResult)
    {
        if (self.package.synchronizeStatus > 0)
            self.package.synchronizeStatus = ATPackageSynchronized;
    }

    // Record package as installed
    self.package.isInstalled = YES;
    [self.package commit];

    // Drop any older versions of this package (if it was installed) from the database
    [[ATDatabase sharedDatabase] executeUpdate:[NSString stringWithFormat:@"DELETE FROM packages WHERE identifier = ? AND RowID <> %u AND isInstalled = 1", self.package.entryID], self.package.identifier, nil];

    [ATPackageManager sharedPackageManager].springboardNeedsRefresh = YES;

    [self.package performSelectorOnMainThread:@selector(pingForAction:) withObject:@"install" waitUntilDone:NO modes:[NSArray arrayWithObjects:NSDefaultRunLoopMode, NSModalPanelRunLoopMode, NSEventTrackingRunLoopMode, nil]];
    [[NSNotificationCenter defaultCenter] performSelectorOnMainThread:@selector(postNotification:) withObject:[NSNotification notificationWithName:ATSourceUpdatedNotification object:self.package.source userInfo:nil] waitUntilDone:NO modes:[NSArray arrayWithObjects:NSDefaultRunLoopMode, NSModalPanelRunLoopMode, NSEventTrackingRunLoopMode, nil]];

    [[ATPackageManager sharedPackageManager] updateApplicationBadge];

    if (installResult)
        [[ATPipelineManager sharedManager] taskDoneWithSuccess:self];
    else
        [[ATPipelineManager sharedManager] taskDoneWithError:self error:[[notification userInfo] objectForKey:IAPhonePackageProcessErrorKey]];
#endif // INSTALLER_APP
}

- (void)embedLuaObjectsInto:(NSMutableArray*)array
{
    for (NSMutableArray* cmdArr in array)
    {
        NSString* cmd = [cmdArr objectAtIndex:0];
        if ([cmd isEqualToString:@"RunScript"])
        {
            // embed
            if ([[cmdArr objectAtIndex:1] isKindOfClass:[NSData class]])
                continue;

            NSString* scriptname = [cmdArr objectAtIndex:1];

            if ([scriptname isAbsolutePath])
                continue;

            NSString* tempName = [[NSFileManager defaultManager] tempFilePath];
            if ([self.script.unpacker copyCompressedPath:scriptname toFileSystemPath:tempName])
            {
                NSData* scriptData = [NSData dataWithContentsOfFile:tempName options:0 error:nil];
                if (scriptData != nil)
                    [cmdArr replaceObjectAtIndex:1 withObject:scriptData];

                [[NSFileManager defaultManager] removeItemAtPath:tempName error:nil];
            }
        }
        else if ([cmd isEqualToString:@"If"] || [cmd isEqualToString:@"IfNot"])
        {
            NSMutableArray* ifarr = [cmdArr objectAtIndex:1];
            NSMutableArray* thenarr = [cmdArr objectAtIndex:2];

            [self embedLuaObjectsInto:ifarr];
            [self embedLuaObjectsInto:thenarr];
        }
    }
}

@end
