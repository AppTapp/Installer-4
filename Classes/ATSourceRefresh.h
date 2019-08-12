//
//  ATSourceRefresh.h
//  Installer
//
//  Created by Slava Karpenko on 7/8/08.
//  Copyright 2008 RiP Dev. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ATTask.h"
#import "ATCydiaRepositoryNode.h"

@class ATSource, ATURLDownload;

@interface ATSourceRefresh : NSObject <ATTask, ATCydiaRepositoryNodeDelegate> {
	ATSource*		source;
	ATURLDownload*	download;
	NSString*		tempFileName;
	
	NSString*		description;

    BOOL cydiaSource;
    ATCydiaRepositoryNode* rootNode;
	
	double progress;
	BOOL			canCancel;
}

@property (retain) ATSource* source;
@property (retain) ATURLDownload* download;
@property (retain) NSString* tempFileName;
@property (retain) NSString* description;
@property (assign) BOOL canCancel;

+ (ATSourceRefresh*)sourceRefreshWithSourceLocation:(NSString*)location;
+ (ATSourceRefresh*)sourceRefreshWithSource:(ATSource*)src;
- (ATSourceRefresh*)initWithSource:(ATSource*)src;

@end
