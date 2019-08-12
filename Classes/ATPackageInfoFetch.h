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

@interface ATPackageInfoFetch : NSObject <ATTask> {
	ATPackage *			package;
	ATURLDownload *		download;
	NSString *			tempFileName;
}

@property (retain) ATPackage * package;
@property (retain) ATURLDownload * download;
@property (retain) NSString * tempFileName;

- initWithPackage:(ATPackage*)pack;

@end
