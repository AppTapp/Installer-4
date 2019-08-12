//
//  ATPipeline.h
//  Installer
//
//  Created by Slava Karpenko on 7/5/08.
//  Copyright 2008 RiP Dev. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ATTask.h"

/* 
	An abstract class representing a "pipeline" of tasks. When one task finishes, next task executes. If the task finishes with an error,
	stop execution and nuke all other tasks that depend on it in the pipeline.
	
	There are different pipeline types coerced into groups. This all is managed by ATPipelineManager.
*/

@interface ATPipeline : NSObject
{
@private
    NSMutableArray* tasks;
    id currentTask;

    NSThread* thread;
    NSRecursiveLock* lock;
}

- (id)currentTask;

- (BOOL)addTask:(id<ATTask>)task;

- (void)markTaskAsDone:(id)task withError:(NSError*)error;

- (id<ATTask>)taskForIdentifier:(NSString*)identifier;

- (NSUInteger)indexOfTask:(id<ATTask>)task;

- (BOOL)existTaskWithPrefix:(NSString*)prefix ignoreTask:(id<ATTask>)ignoreTask;

@end
