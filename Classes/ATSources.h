//
//  ATSources.h
//  Installer
//
//  Created by Maksim Rogov on 05/07/08.
//  Copyright 2008 Nullriver, Inc.. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ATSource.h"


@interface ATSources : NSObject {

}

- (unsigned int)count;
- (ATSource *)sourceAtIndex:(unsigned int)index;
- (ATSource *)sourceWithLocation:(NSString*)locationString;
- (BOOL)addSourceWithLocation:(NSString *)locationString;
- (BOOL)removeSourceWithLocation:(NSString *)locationString;

@end
