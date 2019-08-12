//
//  ATSource.h
//  Installer
//
//  Created by Maksim Rogov on 22/06/08.
//  Copyright 2008 Nullriver, Inc.. All rights reserved.
//

#ifdef INSTALLER_APP
    #import <AppKit/AppKit.h>
#else
    #import <UIKit/UIKit.h>
#endif // INSTALLER_APP

#import "ATEntity.h"

extern NSString* ATSourceUpdatedNotification;
extern NSString* ATSourceInfoIconChangedNotification;
@interface ATSource : ATEntity {
}

@property (assign, getter=_get_url_location, setter=_set_location:) NSURL * location;
@property (assign, getter=_get_str_name, setter=_set_name:) NSString * name;
@property (assign, getter=_get_str_maintainer, setter=_set_maintainer:) NSString * maintainer;
@property (assign, getter=_get_str_contact, setter=_set_contact:) NSString * contact;
@property (assign, getter=_get_str_category, setter=_set_category:) NSString * category;
@property (assign, getter=_get_url_url, setter=_set_url:) NSURL * url;
@property (assign, getter=_get_str_description, setter=_set_description:) NSString * description;
@property (assign, getter=_get_int_istrusted, setter=_set_istrusted:) NSNumber * isTrusted;
@property (assign, getter=_get_dte_lastrefresh, setter=_set_lastrefresh:) NSDate * lastrefresh;
@property (assign, getter=_get_int_isUnsafe, setter=_set_isUnsafe:) NSNumber * isUnsafe;
@property (assign, getter=_get_int_hasErrors, setter=_set_hasErrors:) NSNumber * hasErrors;
@property (assign, getter=_get_url_icon, setter=_set_icon:) NSURL * iconURL;

#ifdef INSTALLER_APP
    @property (assign, getter=_get_int_iscydiasource, setter=_set_iscydiasource:) NSNumber * isCydiaSource;
    @property (assign, readonly) NSImage* icon;
    @property (assign, readonly) NSImage* localIcon;
#else
    @property (assign, readonly) UIImage* icon;
    @property (assign, readonly) UIImage* localIcon;
#endif // INSTALLER_APP

+ (id)sourceWithID:(sqlite_int64)uid;

- (id)initWithID:(sqlite_int64)uid;
- (BOOL)isTrustedSource;

@end
