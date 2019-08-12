//
//  ATIncompleteDownload.m
//  Installer
//
//  Created by Slava Karpenko on 25/08/2008.
//  Copyright 2008 RiP Dev. All rights reserved.
//

#import "ATIncompleteDownload.h"


@implementation ATIncompleteDownload

+ downloadWithID:(sqlite_int64)uid
{
	return [[[ATIncompleteDownload alloc] initWithID:uid] autorelease];
}

- (id)init
{
	if (self = [super initWithTable:@"incomplete_downloads" entryID:0])
	{
	}
	
	return self;
}

- (id)initWithID:(sqlite_int64)uid
{
	if (self = [super initWithTable:@"incomplete_downloads" entryID:uid])
	{
	}
	
	return self;
}

@end
