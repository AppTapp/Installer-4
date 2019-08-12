//
//  ATPackage.h
//  Installer
//
//  Created by Maksim Rogov on 23/06/08.
//  Copyright 2008 Nullriver, Inc.. All rights reserved.
//

#ifdef INSTALLER_APP
    #import <AppKit/AppKit.h>
#else
    #import <UIKit/UIKit.h>
#endif // INSTALLER_APP

#import "ATPackageManager.h"
#import "ATSource.h"
#import "ATEntity.h"

// Notifications sent after fetchExtendedInfo call.
extern NSString* ATPackageInfoFetchingNotification;
extern NSString* ATPackageInfoDoneFetchingNotification;
extern NSString* ATPackageInfoErrorFetchingNotification;
extern NSString* ATPackageInfoIconChangedNotification;
extern NSString* ATPackageInfoRatingChangedNotification;

typedef enum
{
    ATPackageSynchronized = 1,
    ATPackageSynchronizeOnlyLocal,
    ATPackageSynchronizeOnlyDevice
} ATPackageSynchronizeStatus;

@interface ATPackage : ATEntity
{
	BOOL isSynthetic;
	NSString* syntheticSourceName;
	NSString* syntheticSourceURL;

    // Synchronization.
    ATPackageSynchronizeStatus synchronizeStatus;
    NSString* synchronizeVersion;
}

@property (assign, getter=getSource, setter=setSource:) ATSource * source;
@property (assign, getter=_get_url_moreurl, setter=_set_moreurl:) NSURL * moreURL;		// points to the plist containing more info on the package
@property (assign, getter=_get_url_custominfo, setter=_set_custominfo:) NSURL * customInfoURL;							// extended info, may not be fetched if (source.location == nil)
@property (assign, getter=_get_str_identifier, setter=_set_identifier:) NSString * identifier;
@property (assign, getter=_get_str_name, setter=_set_name:) NSString * name;
@property (assign, getter=_get_str_version, setter=_set_version:) NSString * version;
@property (assign, getter=_get_url_location, setter=_set_location:) NSURL * location;									// extended info, may not be fetched if (source.location == nil)
@property (assign, getter=_get_int_size, setter=_set_size:) NSNumber* size;												// extended info, may not be fetched if (source.location == nil)
@property (assign, getter=_get_str_hash, setter=_set_hash:) NSString * hash;											// extended info, may not be fetched if (source.location == nil)
@property (assign, getter=_get_str_maintainer, setter=_set_maintainer:) NSString * maintainer;							// extended info, may not be fetched if (source.location == nil)
@property (assign, getter=_get_str_sponsor, setter=_set_sponsor:) NSString * sponsor;							// extended info, may not be fetched if (source.location == nil)
@property (assign, getter=_get_url_sponsorURL, setter=_set_sponsorURL:) NSURL * sponsorURL;							// extended info, may not be fetched if (source.location == nil)
@property (assign, getter=_get_str_contact, setter=_set_contact:) NSString * contact;									// extended info, may not be fetched if (source.location == nil)
@property (assign, getter=_get_str_description, setter=_set_description:) NSString * description;
@property (assign, getter=_get_url_url, setter=_set_url:) NSURL * url;													// extended info, may not be fetched if (source.location == nil)
@property (assign, getter=_get_str_category, setter=setCategory:) NSString * category;
@property (assign, getter=_get_dte_date, setter=_set_date:) NSDate * date;
@property (assign, getter=_get_arr_dependencies, setter=_set_dependencies:) NSMutableArray* dependencies;				// extended info, may not be fetched if (source.location == nil)
@property (assign, getter=_get_url_icon, setter=_set_icon:) NSURL * iconURL;

@property (assign, getter=_get_dte_ratingRefresh, setter=_set_ratingRefresh:) NSDate* ratingRefresh;
@property (assign, getter=_get_dbl_rating, setter=_set_rating:) NSNumber* rating;
@property (assign, getter=_get_dbl_myRating, setter=setMyRating:) NSNumber* myRating;

#ifdef INSTALLER_APP
@property (assign) BOOL isEssential;
@property (assign) BOOL isCydiaPackage;
@property (assign, readonly) NSImage* icon;
@property (assign, readonly) NSImage* localIcon;
@property (assign, getter=_get_arr_conflicts, setter=_set_conflicts:) NSArray* conflicts;
#else
@property (assign, readonly) UIImage* icon;
@property (assign, readonly) UIImage* localIcon;
#endif // INSTALLER_APP

@property (assign, getter=_get_arr_uninstallScript, setter=_set_uninstallScript:) NSMutableArray* uninstallScript;
@property (assign, getter=_get_arr_preflightScript, setter=_set_preflightScript:) NSMutableArray* preflightScript;
@property (assign, getter=_get_arr_postflightScript, setter=_set_postflightScript:) NSMutableArray* postflightScript;

@property (assign) BOOL isInstalled;
@property (assign, readonly) BOOL hasUpdateAvailable;
@property (readonly) ATPackage* packageUpdate;
@property (assign) BOOL isSynthetic;
@property (retain) NSString* syntheticSourceName;
@property (retain) NSString* syntheticSourceURL;

@property (assign) ATPackageSynchronizeStatus synchronizeStatus;
@property (retain) NSString* synchronizeVersion;

+ (id)packageWithID:(sqlite_int64)uid;

- (id)initWithID:(sqlite_int64)uid;

- (BOOL)needExtendedInfoFetch;

// If needExtendedInfoFetch returns YES, you have to manually initiate the info fetch by calling the method below.
// When the info is done fetching, the ATPackageInfoDoneFetchingNotification will be posted. Meanwhile, you should display something like "Loading" to the user.
// The reason we did this to be fetched manually is because it's an unncessary burden to manually override all the properties.
- (void)fetchExtendedInfo;

- (ATSource *)source;
- (BOOL)isValidPackage;
- (BOOL)isTrustedPackage;
- (BOOL)isNewPackage;
- (int)caseInsensitiveComparePackageName:(ATPackage *)comparePackage;
- (int)caseInsensitiveComparePackageCategory:(ATPackage *)comparePackage;
- (int)comparePackageDate:(ATPackage *)comparePackage;

- (BOOL)install:(NSError**)outError; // Install or upgrade the package
- (BOOL)_install:(NSError**)outError; // Install or upgrade the package (don't call directly)
- (BOOL)uninstall:(NSError**)outError;		// Uninstall the package

- (BOOL)installUSB:(NSError**)outError; // Install or upgrade the package through USB connection.
- (BOOL)_installUSB:(NSError**)outError; // Install or upgrade the package through USB connection (don't call directly)
- (BOOL)uninstallUSB:(NSError**)outError; // Uninstall the package through USB connection.

- (void)pingForAction:(NSString*)action;

- (BOOL)recursiveDependence;
- (void)synchronize;
- (void)removeDownloadFile;
- (BOOL)isConstantPackage;

@end
