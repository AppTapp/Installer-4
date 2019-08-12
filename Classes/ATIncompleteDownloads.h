//
//  ATIncompleteDownloads.h
//  Installer
//
//  Created by Slava Karpenko on 25/08/2008.
//  Copyright 2008 RiP Dev. All rights reserved.
//

#import <Foundation/Foundation.h>

@class ATIncompleteDownload;

@interface ATIncompleteDownloads : NSObject {

}

- (ATIncompleteDownload *)downloadWithLocation:(NSURL*)url;
- (void)cleanupTempFolder;

@end
