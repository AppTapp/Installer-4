//
//  ATSources.m
//  Installer
//
//  Created by Maksim Rogov on 05/07/08.
//  Copyright 2008 Nullriver, Inc.. All rights reserved.
//

#import "ATSources.h"
#import "ATDatabase.h"
#import "ATResultSet.h"
#import "ATPackageManager.h"

@implementation ATSources

- (unsigned int)count {
	NSString * query = @"SELECT COUNT(RowID) AS count FROM sources";
	ATResultSet * res = [[ATDatabase sharedDatabase] executeQuery:query];

	if(res && [res next]) {
		unsigned int count = [res intForColumn:@"count"];
		[res close];
		
		return count;
	}
	
	[res close];
	
	return 0;
}

- (ATSource *)sourceAtIndex:(unsigned int)index {
	NSString * query = [NSString stringWithFormat:@"SELECT RowID FROM sources ORDER BY name ASC, category ASC LIMIT %u,1", index];
	ATResultSet * res = [[ATDatabase sharedDatabase] executeQuery:query];

	if(res && [res next]) {
		ATSource* src = [[[ATSource alloc] initWithID:[res intForColumn:@"RowID"]] autorelease];
		[res close];
		return src;
	}
	
	[res close];
	
	return nil;
}

- (ATSource *)sourceWithLocation:(NSString*)locationString {
	ATResultSet * res = [[ATDatabase sharedDatabase] executeQuery:@"SELECT RowID FROM sources WHERE location = ? LIMIT 1", locationString];
	
	if(res && [res next]) {
		ATSource* src = [[[ATSource alloc] initWithID:[res intForColumn:@"RowID"]] autorelease];
		[res close];
		return src;
	}
	
	[res close];
	
	return nil;
}

- (BOOL)addSourceWithLocation:(NSString *)locationString {
	ATSource * source = [self sourceWithLocation:locationString];
	
	if(source) return NO;
	
	source = [[[ATSource alloc] init] autorelease];
	
	source.location = [NSURL URLWithString:locationString];
	source.name = @"Untitled Source";
	
	[source commit];
	
	[[ATPackageManager sharedPackageManager] refreshSource:source];
	
	return YES;
}

- (BOOL)removeSourceWithLocation:(NSString *)locationString {
	ATSource * source = [self sourceWithLocation:locationString];
	
	if(source != nil) {
		[source remove];
		
		//[delegate performSelector:@selector(packageManager:didRemoveSource:) withObject:self withObject:source];
		
		return YES;
	}
	
	return NO;
}

@end
