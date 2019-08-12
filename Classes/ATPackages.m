//
//  ATPackages.m
//  Installer
//
//  Created by Maksim Rogov on 05/07/08.
//  Copyright 2008 Nullriver, Inc.. All rights reserved.
//

#import "ATPackages.h"
#import "ATPackage.h"
#import "ATSource.h"
#import "ATResultSet.h"
#import "ATDatabase.h"
#import "ATPipelineManager.h"

static void SqliteDateName(sqlite3_context*,int,sqlite3_value**);

@implementation ATPackages

@synthesize sortCriteria;
@synthesize whereClause;
@synthesize sortAscending;
@synthesize resultsLimit;
@synthesize setCount;
@synthesize sectionCount;
@synthesize customQuery;

- (id)init
{
	if (self = [super init])
	{
		lock = [[NSLock alloc] init];
		[lock setName:@"PackagesLock"];

#ifdef INSTALLER_APP
        [[ATDatabase sharedDatabase] executeUpdate:@"ALTER TABLE packages ADD isEssential INTEGER DEFAULT 0"];
        [[ATDatabase sharedDatabase] executeUpdate:@"ALTER TABLE packages ADD isCydiaPackage INTEGER DEFAULT 0"];
        [[ATDatabase sharedDatabase] executeUpdate:@"ALTER TABLE packages ADD conflicts BLOB DEFAULT NULL"];
		[[ATDatabase sharedDatabase] executeUpdate:@"UPDATE packages SET source = NULL WHERE source NOT IN (SELECT RowID FROM sources)"];
#endif // INSTALLER_APP

		[self rebuildWithAllPackagesSortedByCategory];
	}

	return self;
}

- (void)dealloc
{
	[lock release];
    [sortPackagesTableName release];
    [packageSectionNamesTableName release];

	[super dealloc];
}

- (void)rebuildWithAllPackagesSortedByCategory
{
#ifdef INSTALLER_APP
	self.sortCriteria = @"packages.category";
	self.sortAscending = YES;
	self.whereClause = @"packages.isInstalled <> 1";
	self.resultsLimit = 0;
	self.customQuery = nil;
#else
	self.sortCriteria = @"category";
	self.sortAscending = YES;
	self.whereClause = @"isInstalled <> 1";
	self.resultsLimit = 0;
	self.customQuery = nil;
#endif // INSTALLER_APP

	[self rebuild];
}

- (void)rebuildWithAllPackagesSortedAlphabeticallyWithSortCriteria:(NSString*)criteria
{
#ifdef INSTALLER_APP
    if (criteria != nil)
    {
        if (![criteria hasPrefix:@"sources."])
            criteria = [@"packages." stringByAppendingString:criteria];

        self.sortCriteria = criteria;
    }
    else
        self.sortCriteria = @"packages.name";

	self.sortAscending = YES;
	self.whereClause = @"packages.isInstalled <> 1";
	self.resultsLimit = 0;
	self.customQuery = nil;
#else
    if (criteria != nil)
        self.sortCriteria = criteria;
    else
        self.sortCriteria = @"name";

	self.sortAscending = YES;
	self.whereClause = @"isInstalled <> 1";
	self.resultsLimit = 0;
	self.customQuery = nil;
#endif // INSTALLER_APP
	
	[self rebuild];
}

- (void)rebuildWithAllPackagesSortedAlphabetically
{
#ifdef INSTALLER_APP
	self.sortCriteria = @"packages.name";
	self.sortAscending = YES;
	self.whereClause = @"packages.isInstalled <> 1";
	self.resultsLimit = 0;
	self.customQuery = nil;
#else
	self.sortCriteria = @"name";
	self.sortAscending = YES;
	self.whereClause = @"isInstalled <> 1";
	self.resultsLimit = 0;
	self.customQuery = nil;
#endif // INSTALLER_APP
	
	[self rebuild];
}

- (void)rebuildWithInstalledPackages
{
#ifdef INSTALLER_APP
	self.sortCriteria = @"packages.category";
	self.sortAscending = YES;
	self.whereClause = @"packages.isInstalled = 1";
	self.resultsLimit = 0;
	self.customQuery = nil;
#else
	self.sortCriteria = @"category";
	self.sortAscending = YES;
	self.whereClause = @"isInstalled = 1";
	self.resultsLimit = 0;
	self.customQuery = nil;
#endif // INSTALLER_APP
	
	[self rebuild];
}

- (void)rebuildWithUpdatedPackagesWithSortCriteria:(NSString*)criteria
{
#ifdef INSTALLER_APP
	self.customQuery = @"SELECT DISTINCT a.RowID AS id, SUBSTR(a.name, 1, 1) AS _section, a.name AS sort, a.* FROM packages a, packages b, sources WHERE (a.identifier = b.identifier AND a.RowID <> b.RowID AND a.isInstalled <> 1 AND (a.source = sources.RowID OR a.source IS NULL))";
#else
	self.customQuery = @"SELECT a.RowID AS id, SUBSTR(a.name, 1, 1) AS _section, a.name AS sort, a.* FROM packages a, packages b WHERE a.identifier = b.identifier AND a.RowID <> b.RowID AND a.isInstalled <> 1";
#endif // INSTALLER_APP

    if (criteria != nil)
    {
        if (![criteria hasPrefix:@"sources."])
            criteria = [@"a." stringByAppendingString:criteria];

        self.sortCriteria = criteria;
    }
    else
        self.sortCriteria = @"a.name";

	self.resultsLimit = 0;
	self.sortAscending = YES;

	[self rebuild];
}

- (void)rebuildWithUpdatedPackages
{
#ifdef INSTALLER_APP
	self.customQuery = @"SELECT DISTINCT a.RowID AS id, SUBSTR(a.name, 1, 1) AS _section, a.name AS sort, a.* FROM packages a, packages b, sources WHERE (a.identifier = b.identifier AND a.RowID <> b.RowID AND a.isInstalled <> 1 AND (a.source = sources.RowID OR a.source IS NULL))";
#else
	self.customQuery = @"SELECT a.RowID AS id, SUBSTR(a.name, 1, 1) AS _section, a.name AS sort, a.* FROM packages a, packages b WHERE a.identifier = b.identifier AND a.RowID <> b.RowID AND a.isInstalled <> 1";
#endif // INSTALLER_APP

	self.sortCriteria = @"a.name";
	self.resultsLimit = 0;
	self.sortAscending = YES;

	[self rebuild];
}

- (void)rebuildWithRecentPackagesWithSortCriteria:(NSString*)criteria
{
#ifdef INSTALLER_APP
    if (criteria != nil)
    {
        if (![criteria hasPrefix:@"sources."])
            criteria = [@"packages." stringByAppendingString:criteria];

        self.sortCriteria = criteria;
    }
    else
        self.sortCriteria = @"packages.date";

	self.sortAscending = NO;
	self.whereClause = [NSString stringWithFormat:@"packages.date >= %u AND packages.isInstalled <> 1", (unsigned int)[[NSDate dateWithTimeIntervalSinceNow:-60*60*72] timeIntervalSince1970]];
	self.resultsLimit = 0;
	self.customQuery = nil;
#else
    if (criteria != nil)
        self.sortCriteria = criteria;
    else
        self.sortCriteria = @"date";

	self.sortAscending = NO;
	self.whereClause = [NSString stringWithFormat:@"date >= %u AND isInstalled <> 1", (unsigned int)[[NSDate dateWithTimeIntervalSinceNow:-60*60*72] timeIntervalSince1970]];
	self.resultsLimit = 0;
	self.customQuery = nil;
#endif // INSTALLER_APP

	[self rebuild];
}

- (void)rebuildWithRecentPackages
{
#ifdef INSTALLER_APP
	self.sortCriteria = @"packages.date";
	self.sortAscending = NO;
	self.whereClause = [NSString stringWithFormat:@"packages.date >= %u AND packages.isInstalled <> 1", (unsigned int)[[NSDate dateWithTimeIntervalSinceNow:-60*60*72] timeIntervalSince1970]];
	self.resultsLimit = 0;
	self.customQuery = nil;
#else
	self.sortCriteria = @"date";
	self.sortAscending = NO;
	self.whereClause = [NSString stringWithFormat:@"date >= %u AND isInstalled <> 1", (unsigned int)[[NSDate dateWithTimeIntervalSinceNow:-60*60*72] timeIntervalSince1970]];
	self.resultsLimit = 0;
	self.customQuery = nil;
#endif // INSTALLER_APP

	[self rebuild];
}

- (void)rebuildWithSelectPackagesSortedAlphabeticallyForCategory:(NSString*)category sortCriteria:(NSString*)criteria
{
#ifdef INSTALLER_APP
    if (criteria != nil)
    {
        if (![criteria hasPrefix:@"sources."])
            criteria = [@"packages." stringByAppendingString:criteria];

        self.sortCriteria = criteria;
    }
    else
        self.sortCriteria = @"packages.name";

	self.sortAscending = YES;
	self.whereClause = [NSString stringWithFormat:@"packages.category = '%@' AND packages.isInstalled <> 1", [category sqliteEscapedString]];
	self.resultsLimit = 0;
	self.customQuery = nil;
#else
    if (criteria != nil)
        self.sortCriteria = criteria;
    else
        self.sortCriteria = @"name";

	self.sortAscending = YES;
	self.whereClause = [NSString stringWithFormat:@"category = '%@' AND isInstalled <> 1", [category sqliteEscapedString]];
	self.resultsLimit = 0;
	self.customQuery = nil;
#endif // INSTALLER_APP

	[self rebuild];
}

- (void)rebuildWithSelectPackagesSortedAlphabeticallyForCategory:(NSString *)category
{
#ifdef INSTALLER_APP
	self.sortCriteria = @"packages.name";
	self.sortAscending = YES;
	self.whereClause = [NSString stringWithFormat:@"packages.category = '%@' AND packages.isInstalled <> 1", [category sqliteEscapedString]];
	self.resultsLimit = 0;
	self.customQuery = nil;
#else
	self.sortCriteria = @"name";
	self.sortAscending = YES;
	self.whereClause = [NSString stringWithFormat:@"category = '%@' AND isInstalled <> 1", [category sqliteEscapedString]];
	self.resultsLimit = 0;
	self.customQuery = nil;
#endif // INSTALLER_APP

	[self rebuild];
}

- (void)rebuild
{
	while (![lock tryLock]);
	
	//Log(@"Rebuilding with %@", self.whereClause);

	ATDatabase* db = [ATDatabase sharedDatabase];
	// register custom section function
	
    [db executeUpdate:[NSString stringWithFormat:@"DROP TABLE IF EXISTS %@", [self sortPackagesTableName]]];	// drop previous sorts, if any
	[db executeUpdate:[NSString stringWithFormat:@"DROP TABLE IF EXISTS %@", [self packageSectionNamesTableName]]];	// drop previous sorts, if any
	
	NSString* section = [NSString stringWithFormat:@"%@", self.sortCriteria];
	
	if ([self.sortCriteria isEqualToString:@"name"])
		section = @"UPPER(SUBSTR(name, 1, 1))";
	else if ([self.sortCriteria isEqualToString:@"date"])
	{
		sqlite3_create_function([db db], "DATE_NAME", 1, SQLITE_ANY, NULL, &SqliteDateName, NULL, NULL);
		section = @"DATE_NAME(date)";
	}
	
	// construct the query
	NSString* query = nil;
	
#ifdef INSTALLER_APP
	if (self.customQuery)
	{
		query = [NSString stringWithFormat:@"CREATE TEMP TABLE %@ AS %@ ORDER BY %@ %@ %@", [self sortPackagesTableName],
				 self.customQuery,
				 self.sortCriteria,	// ORDER BY %@
				 (self.sortAscending) ? @"ASC" : @"DESC",	// ... order by %. %@
				 (self.resultsLimit) ? [NSString stringWithFormat:@"LIMIT %u", self.resultsLimit] : @""	// %@ (limit clause)
				 ];		
	}
	else
		query = [NSString stringWithFormat:@"CREATE TEMP TABLE %@ AS SELECT DISTINCT packages.RowID AS id, %@ AS _section, %@ AS sort, packages.* FROM packages, sources WHERE (packages.source = sources.RowID OR packages.source IS NULL) %@ ORDER BY %@ %@ %@",
                            [self sortPackagesTableName],
							section,			// %@ AS _section
							self.sortCriteria,	// %@ AS sort
							(self.whereClause && [self.whereClause length]) ? [NSString stringWithFormat:@"AND (%@)", self.whereClause] : @"", // WHERE RowID = RowID %@
							self.sortCriteria,	// ORDER BY %@
							(self.sortAscending) ? @"ASC" : @"DESC",	// ... order by %. %@
							(self.resultsLimit) ? [NSString stringWithFormat:@"LIMIT %u", self.resultsLimit] : @""	// %@ (limit clause)
						];
#else
	if (self.customQuery)
	{
		query = [NSString stringWithFormat:@"CREATE TEMP TABLE %@ AS %@ ORDER BY %@ %@ %@", [self sortPackagesTableName],
				 self.customQuery,
				 self.sortCriteria,	// ORDER BY %@
				 (self.sortAscending) ? @"ASC" : @"DESC",	// ... order by %. %@
				 (self.resultsLimit) ? [NSString stringWithFormat:@"LIMIT %u", self.resultsLimit] : @""	// %@ (limit clause)
				 ];		
	}
	else
		query = [NSString stringWithFormat:@"CREATE TEMP TABLE %@ AS SELECT RowID AS id, %@ AS _section, %@ AS sort, * FROM packages WHERE RowID = RowID %@ ORDER BY %@ %@ %@",
                            [self sortPackagesTableName],
							section,			// %@ AS _section
							self.sortCriteria,	// %@ AS sort
							(self.whereClause && [self.whereClause length]) ? [NSString stringWithFormat:@"AND (%@)", self.whereClause] : @"", // WHERE RowID = RowID %@
							self.sortCriteria,	// ORDER BY %@
							(self.sortAscending) ? @"ASC" : @"DESC",	// ... order by %. %@
							(self.resultsLimit) ? [NSString stringWithFormat:@"LIMIT %u", self.resultsLimit] : @""	// %@ (limit clause)
						];
#endif // INSTALLER_APP
						
	//Log(@"Query = %@", query);
	
	// create temp table
	[db executeUpdate:query];
	
	// Cache the total number of rows in set
	query = [NSString stringWithFormat:@"SELECT COUNT(RowID) AS count FROM %@", [self sortPackagesTableName]];
	ATResultSet* count = [db executeQuery:query];
	if (count && [count next])
	{
		self.setCount = [count intForColumn:@"count"];
	}
	else
		self.setCount = 0;
		
	[count close];
	
	// Cache the section count
	self.sectionCount = 1;
	
	query = [NSString stringWithFormat:@"CREATE TEMP TABLE %@ AS SELECT DISTINCT _section FROM %@ ORDER BY _section ASC", [self packageSectionNamesTableName], [self sortPackagesTableName]];
	[db executeUpdate:query];
	
	query = [NSString stringWithFormat:@"SELECT COUNT(RowID) AS count FROM %@", [self packageSectionNamesTableName]];
	count = [db executeQuery:query];
	if (count && [count next])
		self.sectionCount = [count intForColumn:@"count"];
	else
		self.sectionCount = 0;
	[count close];
	
	[lock unlock];
}

- (NSUInteger)count
{
	ATResultSet* count = [[ATDatabase sharedDatabase] executeQuery:[NSString stringWithFormat:@"SELECT COUNT(RowID) AS count FROM %@", [self sortPackagesTableName]]];
	if (count && [count next])
	{
		NSUInteger result = [count intForColumn:@"count"];
		
		[count close];
		
		return result;
	}
	[count close];
	
	return 0;
}

/*
- (void)_sanityCheck
{
	int res;
	
	sqlite3_stmt *pStmt;
	sqlite3* db = [[ATDatabase sharedDatabase] db];
    
    rc = sqlite3_prepare(db, "SELECT COUNT(RowID) FROM _package_section_names", -1, &pStmt, 0);
    if (rc != SQLITE_OK && rc != SQLITE_BUSY)
	{
        sqlite3_finalize(pStmt);
		
		Log(@"Sanity check: error #%d after prepare (forcing a rebuild)", rc);
		[self rebuild];
		return;
	}
	
	do
	{
		rc = sqlite3_step(pStmt);
			
		if (SQLITE_BUSY == rc)
		{
			usleep(1);
		}
	} while (SQLITE_BUSY == rc);

	if (rc != SQLITE_OK && rc != SQLITE_DONE)
	{
		Log(@"Forcing a rebuild");
		[self rebuild];
	}
	
    sqlite3_finalize(pStmt);
}
*/

- (NSUInteger)numberOfSections
{	
	return self.sectionCount;
}

- (NSString *)sectionTitleAtIndex:(NSUInteger)section
{
	ATResultSet * secID = [[ATDatabase sharedDatabase] executeQuery:[NSString stringWithFormat:@"SELECT _section FROM %@ ORDER BY RowID ASC LIMIT %u,1", [self packageSectionNamesTableName], section]];
	NSString * sectionName = nil;

	if(secID && [secID next]) {
		sectionName = [secID stringForColumn:@"_section"];
	}
	
	[secID close];

	return sectionName;
}

- (NSString *)trimmedSectionTitleAtIndex:(NSUInteger)section
{
	ATResultSet * secID = [[ATDatabase sharedDatabase] executeQuery:[NSString stringWithFormat:@"SELECT TRIM(_section) AS _section FROM %@ ORDER BY RowID ASC LIMIT %u,1", [self packageSectionNamesTableName], section]];
	NSString * sectionName = nil;

	if(secID && [secID next]) {
		sectionName = [secID stringForColumn:@"_section"];
	}
	
	[secID close];

	return sectionName;
}


- (NSUInteger)numberOfPackagesInSection:(NSUInteger)section
{
	NSString* sectionName = [self sectionTitleAtIndex:section];
	
	if (!sectionName)
	{
		return 0;
	}
	
	ATResultSet* count = [[ATDatabase sharedDatabase] executeQuery:[NSString stringWithFormat:@"SELECT COUNT(RowID) AS count FROM %@ WHERE _section = ?", [self sortPackagesTableName]], sectionName];
	if (count && [count next])
	{
		NSUInteger cnt = [count intForColumn:@"count"];
		[count close];
		
		return cnt;
	}
	
	[count close];
	
	return 0;
}


- (ATPackage*)packageAtIndex:(NSUInteger)index
{
	ATResultSet* res = [[ATDatabase sharedDatabase] executeQuery:[NSString stringWithFormat:@"SELECT id FROM %@ ORDER BY RowID ASC LIMIT %u,1", [self sortPackagesTableName], index]];
	if (res && [res next])
	{
		ATPackage* pack = [ATPackage packageWithID:[res intForColumn:@"id"]];
		[res close];
		
		return pack;
	}
	
	[res close];
	
	return nil;
}

- (ATPackage *)packageAtIndex:(NSUInteger)index ofSection:(NSUInteger)section{
	
	NSString * sectionName = [self sectionTitleAtIndex:section];

	if (sectionName)
	{
		ATResultSet* packageId = [[ATDatabase sharedDatabase] executeQuery:[NSString stringWithFormat:@"SELECT id FROM %@ WHERE _section = ? ORDER BY RowID ASC LIMIT %u,1", [self sortPackagesTableName], index], sectionName];
		if(packageId && [packageId next]) {
			ATPackage * package = [ATPackage packageWithID:[packageId intForColumn:@"id"]];
			
			[packageId close];
			
			return package;
		}
		
		[packageId close];
	}
	
	return nil;
}

#pragma mark -
#pragma mark Searching

- (ATPackage*)packageWithIdentifier:(NSString *)identifier {
	return [self packageWithIdentifier:identifier forSource:nil];
}

- (ATPackage*)packageWithIdentifier:(NSString*)identifier forSource:(ATSource*)source
{
	NSString* query;
	ATPackage* pack = nil;
	
	if (source)
		query = [NSString stringWithFormat:@"SELECT RowID FROM packages WHERE source = %u AND identifier = ? ORDER BY date DESC", source.entryID];
	else
		query = @"SELECT RowID FROM packages WHERE identifier = ? ORDER BY date DESC LIMIT 1";
		
	ATResultSet * res = [[ATDatabase sharedDatabase] executeQuery:query, identifier];
	
	if(res && [res next]) {
		pack = [ATPackage packageWithID:[res intForColumn:@"RowID"]];
	}
	
	[res close];
	
	return pack;
}

- (NSArray*)packagesWithIdentifier:(NSString*)identifier
{
	NSString* query;
	NSMutableArray* arr = [NSMutableArray arrayWithCapacity:0];
	
	query = @"SELECT RowID FROM packages WHERE identifier = ?";
	
	ATResultSet * res = [[ATDatabase sharedDatabase] executeQuery:query, identifier];
	
	while (res && [res next]) {
		[arr addObject:[ATPackage packageWithID:[res intForColumn:@"RowID"]]];
	}
	
	[res close];
	
	return arr;
}

- (BOOL)packageIsInstalled:(NSString*)identifier
{
	ATResultSet * res = [[ATDatabase sharedDatabase] executeQuery:@"SELECT RowID FROM packages WHERE identifier = ? AND isInstalled = 1", identifier];
	
	if(res && [res next])
	{
		[res close];
		return YES;
	}
	
	[res close];
	
	return NO;
}

#ifdef INSTALLER_APP

- (BOOL)packageIsEssential:(NSString*)identifier
{
    BOOL result = NO;

	ATResultSet* res = [[ATDatabase sharedDatabase] executeQuery:@"SELECT RowID FROM packages WHERE identifier = ? AND isEssential = 1", identifier];
	if (res != nil && [res next])
		result = YES;

	[res close];

	return result;
}

- (BOOL)packageIsCydiaPackage:(NSString*)identifier
{
    BOOL result = NO;

	ATResultSet* res = [[ATDatabase sharedDatabase] executeQuery:@"SELECT RowID FROM packages WHERE identifier = ? AND isCydiaPackage = 1", identifier];
	if (res != nil && [res next])
		result = YES;

	[res close];

	return result;
}

#endif // INSTALLER_APP

- (ATPackage*)hasInstallerUpdate
{
	NSString* query = @"SELECT a.RowID AS id FROM packages a, packages b WHERE a.identifier = b.identifier AND a.identifier = ? AND a.RowID <> b.RowID AND a.isInstalled <> 1";
	ATResultSet* res = [[ATDatabase sharedDatabase] executeQuery:query, __INSTALLER_BUNDLE_IDENTIFIER__];
	ATPackage* p = nil;
	
	if (res && [res next])
		p = [ATPackage packageWithID:[res intForColumn:@"id"]];

	[res close];
	
	return p;
}

- (NSUInteger)countOfUpdatedPackages
{
	NSString* query = @"SELECT COUNT(a.RowID) AS cnt FROM packages a, packages b WHERE a.identifier = b.identifier AND a.RowID <> b.RowID AND a.isInstalled <> 1";
	ATResultSet* res = [[ATDatabase sharedDatabase] executeQuery:query];
	int r = 0;
	
	if (res && [res next])
		r = [res intForColumn:@"cnt"];
	
	[res close];
	
	return r;
}

- (NSUInteger)countOfPackagesInCategory:(NSString*)category
{
	NSString* query = @"SELECT COUNT(RowID) AS cnt FROM packages WHERE category = ? AND isInstalled <> 1";
	ATResultSet* res = [[ATDatabase sharedDatabase] executeQuery:query, category];
	int r = 0;
	
	if (res && [res next])
		r = [res intForColumn:@"cnt"];
	
	[res close];
	
	return r;
}

- (NSString*)sortPackagesTableName
{
    if (sortPackagesTableName == nil)
        sortPackagesTableName = [@"_package_sort" retain];

    return sortPackagesTableName;
}

- (void)setSortPackagesTableName:(NSString*)tableName
{
    if (![tableName isEqualToString:sortPackagesTableName])
    {
        [sortPackagesTableName release];
        sortPackagesTableName = [tableName retain];
    }
}

- (NSString*)packageSectionNamesTableName
{
    if (packageSectionNamesTableName == nil)
        packageSectionNamesTableName = [@"_package_section_names" retain];

    return packageSectionNamesTableName;
}

- (void)setPackageSectionNamesTableName:(NSString*)tableName
{
    if (![tableName isEqualToString:packageSectionNamesTableName])
    {
        [packageSectionNamesTableName release];
        packageSectionNamesTableName = [tableName retain];
    }
}

@end

#pragma mark -

static void SqliteDateName(sqlite3_context* db,int numArgs, sqlite3_value** args)
{
	NSString* result = nil;
	NSDate* packageDate = nil;
	
	double dbl = sqlite3_value_double(args[0]);
	
	packageDate = [NSDate dateWithTimeIntervalSince1970:dbl];
	
	if ([packageDate timeIntervalSinceNow] < -24.0f * 60.0f * 60.0f)
		result = [NSString stringWithFormat:@"  %@", NSLocalizedString(@"Today", @"")];
	else if ([packageDate timeIntervalSinceNow] < -48.0f * 60.0f * 60.0f)
		result = [NSString stringWithFormat:@" %@", NSLocalizedString(@"Yesterday", @"")];
	else
		result = NSLocalizedString(@"Older", @"");
		
	sqlite3_result_text(db, [result UTF8String], -1, SQLITE_TRANSIENT);
}
