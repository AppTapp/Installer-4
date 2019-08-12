//
//  ATPackages.h
//  Installer
//
//  Created by Maksim Rogov on 05/07/08.
//  Copyright 2008 Nullriver, Inc.. All rights reserved.
//

#import <Foundation/Foundation.h>

@class ATSource;
@class ATPackage;
@class ATResultSet;

@interface ATPackages : NSObject {
	NSString *		sortCriteria;
	NSString *		whereClause;
	NSString *		customQuery;
	BOOL			sortAscending;
	NSUInteger		resultsLimit;
	NSUInteger		setCount;
	NSUInteger		sectionCount;
	
	NSLock * lock;

    NSString* sortPackagesTableName;
    NSString* packageSectionNamesTableName;
}

@property (retain) 	NSString *		sortCriteria;
@property (retain)	NSString *		whereClause;
@property (retain)	NSString *		customQuery;
@property (assign)	BOOL			sortAscending;
@property (assign)	NSUInteger		resultsLimit;
@property (assign)	NSUInteger		setCount;
@property (assign)	NSUInteger		sectionCount;

- (void)rebuildWithAllPackagesSortedByCategory;
- (void)rebuildWithAllPackagesSortedAlphabeticallyWithSortCriteria:(NSString*)criteria;
- (void)rebuildWithAllPackagesSortedAlphabetically;
- (void)rebuildWithInstalledPackages;
- (void)rebuildWithUpdatedPackagesWithSortCriteria:(NSString*)criteria;
- (void)rebuildWithUpdatedPackages;
- (void)rebuildWithRecentPackagesWithSortCriteria:(NSString*)criteria;
- (void)rebuildWithRecentPackages;
- (void)rebuildWithSelectPackagesSortedAlphabeticallyForCategory:(NSString *)category sortCriteria:(NSString*)criteria;
- (void)rebuildWithSelectPackagesSortedAlphabeticallyForCategory:(NSString *)category;
- (void)rebuild;

- (NSUInteger)count;
- (NSUInteger)numberOfSections;
- (NSString *)sectionTitleAtIndex:(NSUInteger)section;
- (NSString *)trimmedSectionTitleAtIndex:(NSUInteger)section;
- (NSUInteger)numberOfPackagesInSection:(NSUInteger)section;
- (ATPackage*)packageAtIndex:(NSUInteger)index;
- (ATPackage *)packageAtIndex:(NSUInteger)index ofSection:(NSUInteger)section;

- (ATPackage*)packageWithIdentifier:(NSString*)identifier;
- (ATPackage*)packageWithIdentifier:(NSString *)identifier forSource:(ATSource *)source;

- (NSArray*)packagesWithIdentifier:(NSString*)identifier;

- (BOOL)packageIsInstalled:(NSString*)identifier;

#ifdef INSTALLER_APP
- (BOOL)packageIsEssential:(NSString*)identifier;
- (BOOL)packageIsCydiaPackage:(NSString*)identifier;
#endif // INSTALLER_APP

- (NSUInteger)countOfUpdatedPackages;
- (ATPackage*)hasInstallerUpdate;
- (NSUInteger)countOfPackagesInCategory:(NSString*)category;

//- (void)_sanityCheck;

- (NSString*)sortPackagesTableName;
- (void)setSortPackagesTableName:(NSString*)tableName;

- (NSString*)packageSectionNamesTableName;
- (void)setPackageSectionNamesTableName:(NSString*)tableName;

@end
