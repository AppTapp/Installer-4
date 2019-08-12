//
//  ATPackageInstallTask.h
//  Installer
//
//  Created by Slava Karpenko on 7/12/08.
//  Copyright 2008 RiP Dev. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "ATTask.h"

@class ATPackage;
@class ATURLDownload;
@class ATScript;

@interface ATPackageInstallTask : NSObject <ATTask> {
	ATPackage *			package;
	ATURLDownload *		download;
	NSString *			tempFileName;
	ATScript *			script;
	
	NSNumber *			progress;
	NSString *			status;
	
	NSUInteger			downloadBytes;
	
	BOOL				canCancel;
}

@property (retain) ATPackage * package;
@property (retain) ATURLDownload * download;
@property (retain) NSString * tempFileName;
@property (retain) ATScript * script;
@property (retain) NSNumber * progress;
@property (retain) NSString * status;
@property (assign) NSUInteger downloadBytes;
@property (assign) BOOL canCancel;

- initWithPackage:(ATPackage*)pack;
- (void)embedLuaObjectsInto:(NSMutableArray*)array;

@end
