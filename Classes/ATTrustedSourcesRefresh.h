//
//  ATTrustedSourcesRefresh.h
//  Installer
//
//  Created by Slava Karpenko on 7/30/08.
//  Copyright 2008 RiP Dev. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "ATTask.h"
#import "ATURLDownload.h"

@interface ATTrustedSourcesRefresh : NSObject <ATTask> {
	ATURLDownload *		download;
	NSString *			tempFileName;
}

@property (retain) ATURLDownload * download;
@property (retain) NSString * tempFileName;

@end
