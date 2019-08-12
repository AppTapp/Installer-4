//
//  ATPipelineManager.m
//  Installer
//
//  Created by Slava Karpenko on 7/5/08.
//  Copyright 2008 RiP Dev. All rights reserved.
//

#import "ATPipelineManager.h"
#import "ATPipeline.h"
#import "ATTask.h"

static ATPipelineManager* sPipelineManager = nil;

// Various constants
NSString* ATPipelinePackageOperation = @"package.ops";
NSString* ATPipelineSourceRefresh = @"source.ops";
NSString* ATPipelineMisc = @"misc";
NSString* ATPipelineSearch = @"search";
NSString* ATPipelineErrors = @"errors";
NSString* ATPipelineSynchronization = @"synchronization";

NSString* ATPipelineTaskQueuedNotification = @"com.ripdev.installer.task.queued";
NSString* ATPipelineTaskFinishedNotification = @"com.ripdev.installer.task.finished";
NSString* ATPipelineTaskStatusNotification = @"com.ripdev.installer.task.status";
NSString* ATPipelineTaskProgressNotification = @"com.ripdev.installer.task.progress";
NSString* ATPipelineTaskChangedNotification = @"com.ripdev.installer.task.changed";
NSString* ATPipelineUserInfoPipelineID = @"pipelineID";
NSString* ATPipelineUserInfoTaskID = @"taskID";
NSString* ATPipelineUserInfoSuccess = @"success"; 
NSString* ATPipelineUserInfoError = @"error";		// if ATPipelineUserInfoSuccess == [NSNumber boolValue] == NO
NSString* ATPipelineUserInfoProgress = @"progress";		// NSNumber, [0.0, 1.0]
NSString* ATPipelineUserInfoStatus = @"status";			// NSString

@implementation ATPipelineManager

@synthesize pipelines;

+ (ATPipelineManager*)sharedManager
{
	if (!sPipelineManager)
	{
		sPipelineManager = [[ATPipelineManager alloc] init];
	}
	
	return sPipelineManager;
}

- init
{
	if (self = [super init])
	{
		pipelinesLock = [[NSLock alloc] init];
		[pipelinesLock setName:@"PipelinesLock"];
		
		self.pipelines = [NSMutableDictionary dictionaryWithCapacity:0];
	}
	
	return self;
}

- (void)dealloc
{
	self.pipelines = nil;
	[pipelinesLock release];
	
	[super dealloc];
}

- (BOOL)queueTask:(id)task forPipeline:(NSString*)pipelineID
{
	// Step 1. Check whether this task is already queued somewhere
	NSString* piID = nil;
	id existingTask = [self findTaskForID:[task taskID] outPipeline:&piID];
	
	if (existingTask && [piID isEqualToString:pipelineID])	// this task is already queued, just return YES and be happy.
	{
		//Log(@"ATPipelineManager: task %@ is already in the pipeline, ignoring.", [task taskID]);
		return YES;
	}
		
	ATPipeline* pipe = [self.pipelines objectForKey:pipelineID];
	if (!pipe)
	{
		//Log(@"ATPipelineManager: Creating new pipeline %@", pipelineID);
		pipe = [[[ATPipeline alloc] init] autorelease];
		
		while (![pipelinesLock tryLock]);
		[self.pipelines setObject:pipe forKey:pipelineID];
		
#ifndef INSTALLER_APP
		[UIApplication sharedApplication].idleTimerDisabled = YES;
#endif // INSTALLER_APP

		[pipelinesLock unlock];
	}
	
	//Log(@"ATPipelineManager: Queuing task %@ into pipeline %@", [task taskID], pipelineID);
	BOOL result = [pipe addTask:task];
	if (result)
	{
		NSArray* allPipelines = [self.pipelines allKeysForObject:[self findPipelineForTask:task]];
		NSString* pipelineID = (allPipelines && [allPipelines count]) ? [allPipelines objectAtIndex:0] : @"";

		NSDictionary* userInfo = [NSDictionary dictionaryWithObjectsAndKeys:[task taskID],		ATPipelineUserInfoTaskID,
																			pipelineID, ATPipelineUserInfoPipelineID,
																			nil];
	
		[[NSNotificationCenter defaultCenter] postNotificationName:ATPipelineTaskQueuedNotification object:task userInfo:userInfo];
	}
	
	return result;
}

- (BOOL)cancelTask:(id)task
{
	ATPipeline* pipe = [self findPipelineForTask:task];
	
	if (!pipe)
		return YES;
	
	if ([task respondsToSelector:@selector(taskCancel)])
		[task performSelector:@selector(taskCancel)];
	
	[self taskDoneWithSuccess:task];
	
	return YES;
}

- (id)findTaskForID:(NSString*)identifier outPipeline:(NSString**)pipelineID
{
    id<ATTask> task = nil;

	while (![pipelinesLock tryLock]);
	
	for (NSString* pipelineKey in self.pipelines)
	{
		ATPipeline* pipe = [self.pipelines objectForKey:pipelineKey];

        task = [pipe taskForIdentifier:identifier];
        if (task != nil)
        {
            if (pipelineID)
                *pipelineID = pipelineKey;

            break;
        }
	}

	[pipelinesLock unlock];

	return task;
}

- (ATPipeline*)findPipelineForTask:(id)task
{
    ATPipeline* pipeline = nil;

	while (![pipelinesLock tryLock]);

	for (NSString* pipelineKey in self.pipelines)
	{
		ATPipeline* pipe = [self.pipelines objectForKey:pipelineKey];

		if ([pipe indexOfTask:task] != NSNotFound)
		{
            pipeline = [[pipe retain] autorelease];
			break;
		}
	}
	
	[pipelinesLock unlock];

	return pipeline;
}

- (NSString*)piplineIDForTask:(id)task
{
    NSString* resultPipelineKey = nil;

	while (![pipelinesLock tryLock]);

	for (NSString* pipelineKey in self.pipelines)
	{
		ATPipeline* pipe = [self.pipelines objectForKey:pipelineKey];

		if ([pipe indexOfTask:task] != NSNotFound)
		{
            resultPipelineKey = [[pipelineKey retain] autorelease];
			break;
		}
	}

	[pipelinesLock unlock];

	return resultPipelineKey;	
}

#pragma mark -
#pragma mark •• Pipeline methods

- (void)pipelineDone:(ATPipeline*)pipeline
{
	while (![pipelinesLock tryLock]);
	
	[self.pipelines removeObjectsForKeys:[self.pipelines allKeysForObject:pipeline]];
		
	if (![self.pipelines count])
	{
#ifndef INSTALLER_APP
		[UIApplication sharedApplication].idleTimerDisabled = NO;
#endif // INSTALLER_APP
	}

	[pipelinesLock unlock];
}

- (void)taskDoneWithError:(id)task error:(NSError*)error
{
	// find the pipeline this task belongs to
	ATPipeline* pipe = [self findPipelineForTask:task];

	if (pipe)
		[pipe markTaskAsDone:task withError:error];
}

- (void)taskDoneWithSuccess:(id)task
{
	ATPipeline* pipe = [self findPipelineForTask:task];

	if (pipe)
		[pipe markTaskAsDone:task withError:nil];	
}

- (void)taskProgressChanged:(id)task
{
	NSArray* allPipelines = [self.pipelines allKeysForObject:[self findPipelineForTask:task]];
	NSString* pipelineID = (allPipelines && [allPipelines count]) ? [allPipelines objectAtIndex:0] : @"";
	
	NSNumber* progress = [NSNumber numberWithDouble:[task taskProgress]];
	NSDictionary* userInfo = [NSDictionary dictionaryWithObjectsAndKeys:	[task taskID],		ATPipelineUserInfoTaskID,
																			pipelineID, ATPipelineUserInfoPipelineID,
																			progress, ATPipelineUserInfoProgress,
																			nil];
	

	NSNotification* notification = [NSNotification notificationWithName:ATPipelineTaskProgressNotification object:task userInfo:userInfo];
	
	[[NSNotificationCenter defaultCenter] performSelectorOnMainThread:@selector(postNotification:) withObject:notification waitUntilDone:NO];
}

- (void)taskStatusChanged:(id)task
{
	NSArray* allPipelines = [self.pipelines allKeysForObject:[self findPipelineForTask:task]];
	NSString* pipelineID = (allPipelines && [allPipelines count]) ? [allPipelines objectAtIndex:0] : @"";
	NSString* status = [task taskDescription];
	NSDictionary* userInfo = [NSDictionary dictionaryWithObjectsAndKeys:	[task taskID],		ATPipelineUserInfoTaskID,
																			pipelineID, ATPipelineUserInfoPipelineID,
																			status, ATPipelineUserInfoStatus,
																			nil];
	

	NSNotification* notification = [NSNotification notificationWithName:ATPipelineTaskStatusNotification object:task userInfo:userInfo];
	
	[[NSNotificationCenter defaultCenter] performSelectorOnMainThread:@selector(postNotification:) withObject:notification waitUntilDone:NO];
}

@end
