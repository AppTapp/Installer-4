//
//  ATEntity.m
//  Installer
//
//  Created by Slava Karpenko on 7/3/08.
//  Copyright 2008 RiP Dev. All rights reserved.
//

#import "ATEntity.h"
#import "ATDatabase.h"
#import "ATResultSet.h"

@implementation ATEntity

@synthesize tableName;
@synthesize entryID;
@synthesize autocommit;

- (id)initWithTable:(NSString*)table entryID:(sqlite_int64)eid
{
	if (self = [super init])
	{
		self.tableName = table;
		self.entryID = eid;
	}
	
	return self;
}

- (void)dealloc
{
	[pendingChanges release];
	[super dealloc];
}

// A little bit of magic. Ye olde black magik.

- (NSMethodSignature *)methodSignatureForSelector:(SEL)aSelector
{
	NSMethodSignature* ms = nil;
	
	if (!strncmp((const char*)aSelector, "_set_", 5))
	{
		ms = [NSMethodSignature signatureWithObjCTypes:"v@:@@"];
	}
	else if (!strncmp((const char*)aSelector, "_get_", 5))
	{
		ms = [NSMethodSignature signatureWithObjCTypes:"@@:@@"];
	}

	return ms ? ms : [super methodSignatureForSelector:aSelector];
}

- (void)forwardInvocation:(NSInvocation *)i
{
	NSString* property = nil;
	const char* sel = (const char*)[i selector];
	
	if (!strncmp(sel, "_set_", 5))
	{
		char propBuffer[128];
		const char* offSel = (sel + sizeof(char)*5);
		
		bzero(propBuffer, sizeof(propBuffer));
		memcpy(propBuffer, offSel, strlen(sel)-6);
		
		property = [NSString stringWithCString:propBuffer];

		if (property)
			[i setArgument:&property atIndex:3];

		[i setSelector:@selector(_set:withProperty:)];
	}
	if (!strncmp(sel, "_get_", 5))
	{
		char propBuffer[128];
		char typeBuffer[16];
		
		const char* typeOffset = (sel + sizeof(char)*5);	// '_get_'
		const char* propOffset = (typeOffset + sizeof(char)*4); // 'typ_'
		
		bzero(propBuffer, sizeof(propBuffer));
		bzero(typeBuffer, sizeof(typeBuffer));
		
		memcpy(typeBuffer, typeOffset, 4);
		memcpy(propBuffer, propOffset, strlen(sel)-9);
		
		property = [NSString stringWithCString:propBuffer];
		if (property)
			[i setArgument:&property atIndex:2];
			
		// Now determine a class
		Class class = [NSString class];	// default is NSString
		
		if (!strcmp(typeBuffer, "dte_"))
			class = [NSDate class];
		else if (!strcmp(typeBuffer, "url_"))
			class = [NSURL class];
		else if (!strcmp(typeBuffer, "int_") || !strcmp(typeBuffer, "dbl_"))
			class = [NSNumber class];
		else if (!strcmp(typeBuffer, "arr_"))
			class = [NSMutableArray class];
		else if (!strcmp(typeBuffer, "dat_"))
			class = [NSData class];
		
		[i setArgument:&class atIndex:3];
		
		[i setSelector:@selector(_get:withClass:)];
	}
	
	[i invoke];
}

- (void)_set:(id)value withProperty:(NSString*)property
{
	if (!value)
		value = [NSNull null];
		
	if (!pendingChanges)
		pendingChanges = [[NSMutableDictionary alloc] initWithCapacity:0];
			
	[pendingChanges setObject:value	forKey:property];
	
	if (self.entryID && self.autocommit)
		[self commit];
}

- (id)_get:(NSString*)property withClass:(Class)class
{
	if ([pendingChanges objectForKey:property])
		return [pendingChanges objectForKey:property];
	
	id retVal = nil;
	
	// Otherwise, query the database
	NSString* query = [NSString stringWithFormat:@"SELECT %@ FROM %@ WHERE RowID = %u", property, self.tableName, self.entryID];
	
	//Log(@"query = %@", query);
	
	ATResultSet* set = [[ATDatabase sharedDatabase] executeQuery:query, nil];
	
	if (set && [set next])
	{
		//Log(@"result = %@", [set stringForColumn:property]);
		
		if (class == [NSDate class])
			retVal = [set dateForColumn:property];
		else if (class == [NSNumber class])
			retVal = [NSNumber numberWithDouble:[set doubleForColumn:property]];
		else if (class == [NSURL class])
		{
			NSString* urlStr = [set stringForColumn:property];
			
			if (urlStr)
				retVal = [NSURL URLWithString:urlStr];
		}
		else if (class == [NSMutableArray class])
		{
			NSData* serializedArr = [set dataForColumn:property];
			
			if (serializedArr)
				retVal = [NSPropertyListSerialization propertyListFromData:serializedArr mutabilityOption:NSPropertyListMutableContainersAndLeaves format:NULL errorDescription:NULL];
			
			if (!retVal)
				retVal = [NSMutableArray arrayWithCapacity:0];
		}
		else if (class == [NSData class])
			retVal = [set dataForColumn:property];
		else		// Default is a string
			retVal = [set stringForColumn:property];
	}
	
	[set close];
	
	return retVal;
}

- (BOOL)commit
{
	if (![pendingChanges count])
		return YES;
	
	if (!self.entryID)		// We do an INSERT statement
	{
		NSMutableArray* setStmts = [NSMutableArray arrayWithCapacity:0];
		NSMutableArray* placeholderStmts = [NSMutableArray arrayWithCapacity:0];
		NSMutableArray* values = [NSMutableArray arrayWithCapacity:0];
		
		for (NSString* property in pendingChanges)
		{
			[setStmts addObject:property];
			[placeholderStmts addObject:@"?"];
			[values addObject:[pendingChanges objectForKey:property]];
		}
		
		NSString* columnsStmt = [setStmts componentsJoinedByString:@", "];	
		NSString* placeholdersStmt = [placeholderStmts componentsJoinedByString:@", "];	
		
		NSString* query = [NSString stringWithFormat:@"INSERT INTO %@ (%@) VALUES(%@)", self.tableName, columnsStmt, placeholdersStmt];
			
		int rc = [[ATDatabase sharedDatabase] executeUpdate:query withArray:values];
		
		if (rc != SQLITE_OK)
			Log(@"INSERT FOR '%@': %d with %@", query, rc, values);
		
		self.entryID = [[ATDatabase sharedDatabase] lastInsertRowId];
		
		//Log(@"INSERT: assigned rowid = %u", self.entryID);
		
		if (rc == SQLITE_OK)
			[pendingChanges removeAllObjects];

		return (rc == SQLITE_OK);
	}
	else					// We do an UPDATE statement
	{
		NSMutableArray* setStmts = [NSMutableArray arrayWithCapacity:0];
		NSMutableArray* values = [NSMutableArray arrayWithCapacity:0];
		
		for (NSString* property in pendingChanges)
		{
			[setStmts addObject:[NSString stringWithFormat:@"%@ = ?", property]];
			[values addObject:[pendingChanges objectForKey:property]];
		}
		
		NSString* setStmt = [setStmts componentsJoinedByString:@", "];
		NSString* query = [NSString stringWithFormat:@"UPDATE %@ SET %@ WHERE RowID = %u", self.tableName, setStmt, self.entryID];
		
		int rc = [[ATDatabase sharedDatabase] executeUpdate:query withArray:values];
		
		if (rc != SQLITE_OK)
			Log(@"UPDATE FOR '%@' (values = %@): %d", query, values, rc);
		
		if (rc == SQLITE_OK)
			[pendingChanges removeAllObjects];

		return (rc == SQLITE_OK);
	}
	
	return NO;
}

- (void)remove
{
	if (!self.entryID)
		return;
	
	[[ATDatabase sharedDatabase] executeUpdate:[NSString stringWithFormat:@"DELETE FROM %@ WHERE RowID = %u", self.tableName, self.entryID]];
	
	self.entryID = 0;		// make us squeaky clean.
}

@end
