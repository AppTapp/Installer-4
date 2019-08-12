//
//  ATQueueFutureInstall.h
//  Installer
//
//  Created by Slava Karpenko on 21/08/2008.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ATTask.h"

@interface ATQueueFutureInstall : NSObject <ATTask> {
	NSString* packageID;
}

@property (retain) NSString* packageID;

- initWithPackageID:(NSString*)identifier;

@end
