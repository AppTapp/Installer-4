//
//  ATPackageUSBUninstallTask.h
//  Installer
//
//  Created by Slava Karpenko on 7/12/08.
//  Copyright 2008 RiP Dev. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "ATTask.h"

@class ATPackage;
@class ATScript;

@interface ATPackageUSBUninstallTask : NSObject <ATTask> {
	ATPackage *			package;
	
	NSNumber *			progress;
	NSString *			status;
}

@property (retain) ATPackage * package;
@property (retain) NSNumber * progress;
@property (retain) NSString * status;

- (id)initWithPackage:(ATPackage*)pack;

@end
