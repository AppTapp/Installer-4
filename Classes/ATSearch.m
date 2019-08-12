//
//  ATSearch.m
//  Installer
//
//  Created by Slava Karpenko on 20/08/2008.
//  Copyright 2008 RiP Dev. All rights reserved.
//

#import "ATDatabase.h"
#import "ATResultSet.h"
#import "ATSearch.h"
#import "ATPackage.h"
#import "ATSource.h"
#import "ATPipelineManager.h"
#import "ATSearchTask.h"

NSString* ATSearchResultsUpdatedNotification = @"com.ripdev.install.search.update";

@implementation ATSearch

- (id)init
{
	if (self = [super init])
    {
		self.searchCriteria = nil;

#ifdef INSTALLER_APP
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(searchUpdated:) name:ATSearchResultsUpdatedNotification object:nil];    

        ATDatabase* database = [ATDatabase sharedDatabase];

        [database executeUpdate:@"ALTER TABLE search ADD category TEXT"];
        [database executeUpdate:@"ALTER TABLE search ADD contact TEXT"];

        [database executeUpdate:@"DROP TABLE IF EXISTS external_search"];
        [database executeUpdate:@"CREATE TABLE external_search (packageID INTEGER DEFAULT NULL, sourceName TEXT, sourceURL TEXT, identifier TEXT, name TEXT, customInfo TEXT, description TEXT, version TEXT, icon TEXT, date REAL, category TEXT, contact TEXT)"];
#endif // INSTALLER_APP
    }

	return self;
}

- (void)dealloc
{
#ifdef INSTALLER_APP
    [[NSNotificationCenter defaultCenter] removeObserver:self name:ATSearchResultsUpdatedNotification object:nil];
#endif // INSTALLER_APP

    [searchCriteria release];
    [_sortCriteria release];

    [super dealloc];
}

#pragma mark -

- (void)setSearchCriteria:(NSString*)criteria
{
	NSString* oldSearchCriteria = searchCriteria;
	
	[searchCriteria autorelease];
	searchCriteria = nil;
	
	if (criteria && ![criteria length])
		criteria = nil;
	
	if (criteria)
	{
		NSMutableString* crit = [NSMutableString stringWithString:[[criteria lowercaseString] stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@" "]]];

		searchCriteria = [crit retain];
	}
	
	if (![oldSearchCriteria isEqualToString:searchCriteria] && [searchCriteria length] >= 3)
		[self _search];
}

- (NSString*)searchCriteria
{
	return searchCriteria;
}

#pragma mark -

- (unsigned int)count
{
	NSString * query = @"SELECT COUNT(RowID) AS count FROM search";
	ATResultSet * res = [[ATDatabase sharedDatabase] executeQuery:query];
	
	if(res && [res next]) {
		unsigned int count = [res intForColumn:@"count"];
		[res close];
		
		return count;
	}
	
	[res close];
	
	return 0;
}

- (ATPackage *)packageAtIndex:(unsigned int)index
{
    NSString* sortCriteria = [self sortCriteria];

#ifdef INSTALLER_APP
    if ([sortCriteria isEqualToString:@"sources.name"])
        sortCriteria = @"sourceName";
#endif // INSTALLER_APP

	NSString * query = [NSString stringWithFormat:@"SELECT * FROM search ORDER BY %@ ASC LIMIT %u,1", sortCriteria, index];

	ATResultSet * res = [[ATDatabase sharedDatabase] executeQuery:query];
	
	if(res && [res next]) {
		unsigned int packageID = [res intForColumn:@"packageID"];
		ATPackage* pack = nil;
		
		if (packageID)
			pack = [[[ATPackage alloc] initWithID:packageID] autorelease];
		else
		{
			pack = [[[ATPackage alloc] init] autorelease];
			pack.syntheticSourceName = [res stringForColumn:@"sourceName"];
			pack.syntheticSourceURL = [res stringForColumn:@"sourceURL"];
			pack.name = [res stringForColumn:@"name"];
			pack.version = [res stringForColumn:@"version"];
			pack.identifier= [res stringForColumn:@"identifier"];
			if ([res stringForColumn:@"customInfo"])
				pack.customInfoURL = [NSURL URLWithString:[res stringForColumn:@"customInfo"]];
			if ([res stringForColumn:@"icon"])
				pack.iconURL = [NSURL URLWithString:[res stringForColumn:@"icon"]];
			pack.description = [res stringForColumn:@"description"];
			pack.date = [res dateForColumn:@"date"];
#ifdef INSTALLER_APP
			pack.category = [res stringForColumn:@"category"];
#endif // INSTALLER_APP
			pack.isSynthetic = YES;
		}
		
		[res close];
		return pack;
	}
	
	[res close];
	
	return nil;
}

#pragma mark -

- (void)searchImmediately
{
	[NSObject cancelPreviousPerformRequestsWithTarget:self];
	[[ATDatabase sharedDatabase] executeUpdate:@"DELETE FROM search;"];
	
	if (!self.searchCriteria || ![self.searchCriteria length])
		return;
	
	// Run search
	
#ifdef INSTALLER_APP
    NSString* sortCriteria = [self sortCriteria];
    if (sortCriteria != nil && ![sortCriteria hasPrefix:@"sources."])
        sortCriteria = [@"packages." stringByAppendingString:sortCriteria];

	NSString* q = [NSString stringWithFormat:@"INSERT INTO search (packageID, name, identifier, category, contact, sourceName) SELECT DISTINCT packages.RowID AS packageID, packages.name AS name, packages.identifier AS identifier, packages.category AS category, packages.contact AS contact, sources.name AS sourceName FROM packages, sources WHERE ((packages.name LIKE ? OR packages.description LIKE ? OR sources.name LIKE ? OR packages.category LIKE ? OR packages.contact LIKE ? OR packages.identifier LIKE ?) AND packages.source = sources.RowID) ORDER BY %@ ASC", sortCriteria];

	NSString* crit = [NSString stringWithFormat:@"%%%@%%", self.searchCriteria];

	[[ATDatabase sharedDatabase] executeUpdate:q, crit, crit, crit, crit, crit, crit];

	q = [NSString stringWithFormat:@"INSERT INTO search (packageID, name, identifier, category, contact) SELECT DISTINCT packages.RowID AS packageID, packages.name AS name, packages.identifier AS identifier, packages.category AS category, packages.contact AS contact FROM packages WHERE ((packages.name LIKE ? OR packages.description LIKE ?) AND packages.source IS NULL) ORDER BY %@ ASC", sortCriteria];

	crit = [NSString stringWithFormat:@"%%%@%%", self.searchCriteria];

	[[ATDatabase sharedDatabase] executeUpdate:q, crit, crit];
#else
	NSString* q = [NSString stringWithFormat:@"INSERT INTO search ( packageID ) SELECT RowID FROM packages WHERE name LIKE ? OR description LIKE ? ORDER BY %@ ASC", [self sortCriteria]];

	NSString* crit = [NSString stringWithFormat:@"%%%@%%", self.searchCriteria];
	
	[[ATDatabase sharedDatabase] executeUpdate:q, crit, crit];
#endif // INSTALLER_APP

	[self performSelector:@selector(_externalSearch) withObject:nil];
}

- (void)_search
{
	[NSObject cancelPreviousPerformRequestsWithTarget:self];
	[[ATDatabase sharedDatabase] executeUpdate:@"DELETE FROM search;"];
	
	if (!self.searchCriteria || ![self.searchCriteria length])
		return;
	
	// Run search
	
#ifdef INSTALLER_APP
    NSString* sortCriteria = [self sortCriteria];
    if (sortCriteria != nil && ![sortCriteria hasPrefix:@"sources."])
        sortCriteria = [@"packages." stringByAppendingString:sortCriteria];

	NSString* q = [NSString stringWithFormat:@"INSERT INTO search (packageID, name, identifier, category, contact, sourceName) SELECT DISTINCT packages.RowID AS packageID, packages.name AS name, packages.identifier AS identifier, packages.category AS category, packages.contact AS contact, sources.name AS sourceName FROM packages, sources WHERE ((packages.name LIKE ? OR packages.description LIKE ? OR sources.name LIKE ? OR packages.category LIKE ? OR packages.contact LIKE ? OR packages.identifier LIKE ?) AND packages.source = sources.RowID) ORDER BY %@ ASC", sortCriteria];

	NSString* crit = [NSString stringWithFormat:@"%%%@%%", self.searchCriteria];
	
	[[ATDatabase sharedDatabase] executeUpdate:q, crit, crit, crit, crit, crit, crit];

	q = [NSString stringWithFormat:@"INSERT INTO search (packageID, name, identifier, category, contact) SELECT DISTINCT packages.RowID AS packageID, packages.name AS name, packages.identifier AS identifier, packages.category AS category, packages.contact AS contact FROM packages WHERE ((packages.name LIKE ? OR packages.description LIKE ?) AND packages.source IS NULL) ORDER BY %@ ASC", sortCriteria];

	crit = [NSString stringWithFormat:@"%%%@%%", self.searchCriteria];

	[[ATDatabase sharedDatabase] executeUpdate:q, crit, crit];
#else
	NSString* q = [NSString stringWithFormat:@"INSERT INTO search ( packageID ) SELECT RowID FROM packages WHERE name LIKE ? OR description LIKE ? ORDER BY %@ ASC", [self sortCriteria]];

	NSString* crit = [NSString stringWithFormat:@"%%%@%%", self.searchCriteria];

	[[ATDatabase sharedDatabase] executeUpdate:q, crit, crit];
#endif // INSTALLER_APP

	[self performSelector:@selector(_externalSearch) withObject:nil afterDelay:3.];
}

- (void)_externalSearch
{
	if (!self.searchCriteria)
		return;
	
	id existingSearchTask = [[ATPipelineManager sharedManager] findTaskForID:@":search" outPipeline:nil];
	if (existingSearchTask)
		[[ATPipelineManager sharedManager] cancelTask:existingSearchTask];
	
	ATSearchTask* st = [[[ATSearchTask alloc] initWithSearch:self] autorelease];
	
	if (st)
		[[ATPipelineManager sharedManager] queueTask:st forPipeline:ATPipelineSearch];
}

- (NSString*)sortCriteria
{
    if (_sortCriteria == nil)
        _sortCriteria = [@"name" retain];

    return _sortCriteria;
}

- (void)setSortCriteria:(NSString*)sortCriteria
{
    if (![_sortCriteria isEqualToString:sortCriteria])
    {
        [_sortCriteria release];
        _sortCriteria = [sortCriteria retain];

        [self searchImmediately];
    }
}

- (void)searchUpdated:(NSNotification*)notification
{
#ifdef INSTALLER_APP
    ATDatabase* database = [ATDatabase sharedDatabase];

	NSString* query = @"SELECT COUNT(RowID) AS count FROM external_search";
	ATResultSet* result = [database executeQuery:query];
	NSInteger searchCount = 0;
    
	if (result != nil && [result next])
		searchCount = (NSInteger)[result intForColumn:@"count"];

    [result close];

    if (searchCount > 0)
    {
        [database executeUpdate:@"INSERT INTO external_search SELECT * FROM search"];
        [database executeUpdate:@"DELETE FROM search;"];

        NSString* sortCriteria = [self sortCriteria];
        if ([sortCriteria isEqualToString:@"sources.name"])
            sortCriteria = @"sourceName";

        [database executeUpdate:[NSString stringWithFormat:@"INSERT INTO search SELECT * FROM external_search ORDER BY %@ ASC", sortCriteria]];
    }
#endif // INSTALLER_APP
}

@end
