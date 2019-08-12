//
//  ATSearch.h
//  Installer
//
//  Created by Slava Karpenko on 20/08/2008.
//  Copyright 2008 RiP Dev. All rights reserved.
//

#import <Foundation/Foundation.h>

@class ATResultSet;
@class ATPackage;

extern NSString* ATSearchResultsUpdatedNotification;

@interface ATSearch : NSObject
{
	NSString* searchCriteria;
	NSString* _sortCriteria;
}

@property (retain) NSString* searchCriteria;

- (unsigned int)count;
- (ATPackage *)packageAtIndex:(unsigned int)index;

- (void)searchImmediately;
- (void)_search;
- (void)_externalSearch;

- (NSString*)sortCriteria;
- (void)setSortCriteria:(NSString*)sortCriteria;

@end
