//
//  ATPackageInfoFetch.h
//  Installer
//
//  Created by Slava Karpenko on 7/11/08.
//  Copyright 2008 RiP Dev. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ATTask.h"

@class ATPackage;
@class ATURLDownload;
@class ATSource;

@interface ATPackageIconFetch : NSObject <ATTask> {
	ATPackage *			package;
	ATSource *			source;
	ATURLDownload *		download;
	NSString *			tempFileName;
}

@property (retain) ATPackage * package;
@property (retain) ATSource * source;
@property (retain) ATURLDownload * download;
@property (retain) NSString * tempFileName;

- initWithPackage:(ATPackage*)pack source:(ATSource*)source;

@end
