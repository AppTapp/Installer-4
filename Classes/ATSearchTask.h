//
//  ATSearchTask.h
//  Installer
//
//  Created by Slava Karpenko on 21/08/2008.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ATTask.h"

@class ATSearch;
@class ATURLDownload;

@interface ATSearchTask : NSObject <ATTask> {
	NSString *			search;
	ATURLDownload *		download;
	NSString *			tempFileName;
}

@property (retain) NSString * search;
@property (retain) ATURLDownload * download;
@property (retain) NSString * tempFileName;

- initWithSearch:(ATSearch*)srch;

@end
