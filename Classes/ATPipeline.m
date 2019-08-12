//
//  ATPipeline.m
//  Installer
//
//  Created by Slava Karpenko on 7/5/08.
//  Copyright 2008 RiP Dev. All rights reserved.
//

#import "ATPipeline.h"
#import "ATPipelineManager.h"
#import "ATDatabase.h"

@implementation ATPipeline

- (id)init
{
	if (self = [super init])
	{
		lock = [[NSRecursiveLock alloc] init];

		[lock setName:@"TasksLock"];
	}
	
	return self;
}

- (void)dealloc
{
	[thread cancel];

	[currentTask release];
	[lock release];
	[tasks release];

	[super dealloc];
}

- (id)currentTask
{
    return [[currentTask retain] autorelease];
}

- (BOOL)addTask:(id<ATTask>)task
{
	// do a few checks before adding the task to the queue.
	//Log(@"ATPipeline: Adding task %@ to %@", [task taskID], self);
	
	// First, check if this task has any dependencies
#ifndef INSTALLER_APP
	if ([task taskDependencies])
	{
		for (NSString* depID in [task taskDependencies])
		{
			if (![[ATPipelineManager sharedManager] findTaskForID:depID	outPipeline:nil])
			{
				//Log(@"ATPipeline: required dependency task %@ is not in the queue. Aborting add.", depID);
				return NO;
			}
		}
	}
#endif // INSTALLER_APP

	[lock lock];

    if (task != nil)
    {
        if (tasks == nil)
            tasks = [[NSMutableArray alloc] initWithCapacity:0];
        
        [tasks addObject:task];
    }

	[lock unlock];
	
	// If we got to this point, then either task has no dependencies, or they all are in the pipeline already. So let's do the mm-bop!
	if (!thread)
	{
		thread = [[NSThread alloc] initWithTarget:self selector:@selector(_thread:) object:nil];
		
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(threadDone:) name:NSThreadWillExitNotification object:thread];
		
		[thread start];
	}
	
	return YES;
}

- (void)markTaskAsDone:(id)task withError:(NSError*)error
{
	//Log(@"ATPipeline %@: task %@ is done (has errors=%@)", self, [task taskID], error);
	
	if (error)
	{
		// Take off all tasks that depend on this one
		NSString* taskID = [task taskID];
		NSArray* localTasks = nil;

        [lock lock];

		localTasks = [NSArray arrayWithArray:tasks];

        [lock unlock];

		for (id<ATTask> tsk in localTasks)
		{
			NSArray* deps = [tsk taskDependencies];
			if (deps && [deps count])
			{
				if ([deps containsObject:taskID])
				{
					//Log(@"ATPipeline: Removing task %@ as it depends on the failed task.", [tsk taskID]);
					[self markTaskAsDone:tsk withError:error];
				}
			}
		}
	}
	
	NSDictionary* userInfo = [NSDictionary dictionaryWithObjectsAndKeys:[task taskID],		ATPipelineUserInfoTaskID,
																		[[[ATPipelineManager sharedManager].pipelines allKeysForObject:self] objectAtIndex:0], ATPipelineUserInfoPipelineID,
																		(error != nil) ? (id)error : (id)[NSNull null], ATPipelineUserInfoError,
																		[NSNumber numberWithBool:(error == nil)], ATPipelineUserInfoSuccess,
																		nil];

	NSNotification* notification = [NSNotification notificationWithName:ATPipelineTaskFinishedNotification object:task userInfo:userInfo];
	
#ifdef INSTALLER_APP
	[[NSNotificationCenter defaultCenter] performSelectorOnMainThread:@selector(postNotification:) withObject:notification waitUntilDone:NO];
#else
	[[NSNotificationCenter defaultCenter] performSelectorOnMainThread:@selector(postNotification:) withObject:notification waitUntilDone:YES];
#endif // INSTALLER_APP

	[lock lock];

	[tasks removeObject:task];

	[lock unlock];
	
	//Log(@"Task %@ removed", task);
	
	if (task == currentTask)
    {
        [currentTask release];
		currentTask = nil;
    }
}

- (id<ATTask>)taskForIdentifier:(NSString*)identifier
{
    id<ATTask> resultTask = nil;

	[lock lock];

    id<ATTask> task = nil;

    for (task in tasks)
    {
        if ([[task taskID] isEqualToString:identifier])
        {
            resultTask = [[(id)task retain] autorelease];
            break;
        }
    }

	[lock unlock];

    return resultTask;
}

- (NSUInteger)indexOfTask:(id<ATTask>)task
{
    NSUInteger indexOfTask = NSNotFound;

	[lock lock];

    indexOfTask = [tasks indexOfObject:task];

	[lock unlock];

    return indexOfTask;
}

- (BOOL)existTaskWithPrefix:(NSString*)prefix ignoreTask:(id<ATTask>)ignoreTask
{
    BOOL result = NO;

	[lock lock];

    id<ATTask> task = nil;

    for (task in tasks)
    {
        if (task == ignoreTask)
            continue;

        if ([[task taskID] hasPrefix:prefix])
        {
            result = YES;
            break;
        }
    }

	[lock unlock];

    return result;
}

#pragma mark -
#pragma mark •• Notifications

- (void)threadDone:(NSNotification*)notification
{
	// The thread is done, let's tell the manager the pipeline is done	
	[[ATPipelineManager sharedManager] pipelineDone:self];
}

#pragma mark -
#pragma mark •• Worker

- (void)_thread:(id)sender
{
	NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
	
	//[NSThread setThreadPriority:0.1];
	
	//Log(@"ATPipeline %@: thread started (priority = %f)", self, [NSThread threadPriority]);
	
loop:		// forgive me father, for I have sinned.
	while (![thread isCancelled])
	{
		NSAutoreleasePool* innerPool = [[NSAutoreleasePool alloc] init];
		
		id nextTask = nil;

        [lock lock];

        if ([tasks count] > 0)
            nextTask = [tasks objectAtIndex:0];

        [lock unlock];

        if (nextTask == nil)
		{
			[innerPool release];
            break;
		}
		
		if (nextTask == currentTask)
		{
			// we're already executing this task, let's sleep a little bit.
			NSAutoreleasePool* reallyInnerPool = [[NSAutoreleasePool alloc] init];
			NSDate* date = [[NSDate alloc] initWithTimeIntervalSinceNow:0.01];
			[[NSRunLoop currentRunLoop] runUntilDate:date];
			[date release];
			[reallyInnerPool release];
		}
		else
		{
			//Log(@"ATPipeline: launching task %@", [nextTask taskID]);

            if (currentTask != nextTask)
            {
                [currentTask release];
                currentTask = [nextTask retain];
            }

			NSNotification* notification = [NSNotification notificationWithName:ATPipelineTaskChangedNotification object:currentTask userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:YES], @"isActiveTask",
															[[[ATPipelineManager sharedManager].pipelines allKeysForObject:self] objectAtIndex:0], ATPipelineUserInfoPipelineID, nil]];
#ifdef INSTALLER_APP
			[[NSNotificationCenter defaultCenter] performSelectorOnMainThread:@selector(postNotification:) withObject:notification waitUntilDone:NO];
#else
			[[NSNotificationCenter defaultCenter] performSelectorOnMainThread:@selector(postNotification:) withObject:notification waitUntilDone:YES];
#endif // INSTALLER_APP

			[currentTask taskStart];
		}
		
		[innerPool release];
	}
	
	// close the database instance for this thread...
	{
		NSNotification* not = [NSNotification notificationWithName:NSThreadWillExitNotification object:[NSThread currentThread]];
		[[ATDatabaseThreadPool sharedPool] threadDidEndNotification:not];
	}
	
	// run a little bit more to see if more tasks will be added
	//NSTimeInterval endDate = [[NSDate dateWithTimeIntervalSinceNow:5.] timeIntervalSinceReferenceDate];
	//Log(@"ATPipeline %@: waiting to see if we'll get more work", self);
    NSInteger tasksCount = 0;
	do
	{
	/*
		NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
		NSDate* date = [[NSDate alloc] initWithTimeIntervalSinceNow:0.05];
		[[NSRunLoop currentRunLoop] runUntilDate:date];
		[date release];
		[pool release];
	*/
		sleep(1);

        [lock lock];

        tasksCount = [tasks count];

        [lock unlock];

	} while (tasksCount == 0 /* && [[NSDate date] timeIntervalSinceReferenceDate] < endDate */);

	if (tasksCount > 0)
	{
		//Log(@"Pipeline %@: more tasks arrived, looping back.", self);
		goto loop;
	}

	//Log(@"ATPipeline %@: thread finished.", self);
	
	[pool release];
	
	sqlite3_thread_cleanup();
}

@end
