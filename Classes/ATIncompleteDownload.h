//
//  ATIncompleteDownload.h
//  Installer
//
//  Created by Slava Karpenko on 25/08/2008.
//  Copyright 2008 RiP Dev. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ATEntity.h"

@interface ATIncompleteDownload : ATEntity {
}

@property (assign, getter=_get_url_url, setter=_set_url:) NSURL * url;
@property (assign, getter=_get_str_path, setter=_set_path:) NSString * path;
@property (assign, getter=_get_dte_date, setter=_set_date:) NSDate * date;
@property (assign, getter=_get_int_size, setter=_set_size:) NSNumber * size;
@property (assign, getter=_get_dte_mod_date, setter=_set_mod_date:) NSDate * modDate;

+ downloadWithID:(sqlite_int64)uid;

- (id)initWithID:(sqlite_int64)uid;

@end
