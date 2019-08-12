//
//  ATUnpacker.m
//
//  Created by Adam Dann on 15/09/07.
//  Copyright 2007 Nullriver, Inc. All rights reserved.
//

#import <fcntl.h>
#import "ATUnpacker.h"

#if !defined(ATCORE)
	#import "ATPackageManager.h"
#endif

@implementation ATUnpacker

@synthesize packageID;

#pragma mark -
#pragma mark Factory

- (id)initWithPath:(NSString *)path packageID:(NSString*)pid {
	if((self = [super init])) {
		self.packageID = pid;
		
		if((zipFile = unzOpen([path cStringUsingEncoding:NSASCIIStringEncoding]))) {
			ignoredPaths = [[NSArray arrayWithObjects:@"__MACOSX", @".svn", @".cvs", @".DS_Store", nil] retain];
		} else {
			Log(@"ATUnpacker: Could not open zip file: %@", path);
			[self autorelease];

			return nil;
		}
	}

	return self;
}

-(void)dealloc {
	self.packageID = nil;
	
	[ignoredPaths release];
	if(zipFile != nil) unzClose(zipFile);

	[super dealloc];
}


#pragma mark -
#pragma mark Accessors

- (void)setIgnoredPaths:(NSArray *)pathsToIgnore {
	[pathsToIgnore retain];
	[ignoredPaths release]; 
	ignoredPaths = pathsToIgnore;
}

- (NSArray *)ignoredPaths {
	return ignoredPaths;
}


#pragma mark -
#pragma mark Methods 
                
- (BOOL)shouldIgnorePath:(NSString *)aPath
{
	NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
	BOOL res = ([ignoredPaths firstObjectCommonWithArray:[aPath pathComponents]] != nil);
	[pool release];
	return res;
}
         
// control loop - mimic ditto
// filea > fileb - copy filea over fileb
// file > dir  - copy file into dir
// dira > dirb - copy contents of dira into dirb

- (BOOL)copyCompressedPath:(NSString *)source toFileSystemPath:(NSString *)destination {
	Log(@"ATUnpacker: Copying compressed path: %@ >> %@", source, destination);
	BOOL result = YES;

	if(![destination isAbsolutePath]) {
		Log(@"ATUnpacker: Destination is not absolute path!");
		return NO;
	}
	
#if __i386__
	if (![destination hasPrefix:NSTemporaryDirectory()])
		destination = @"/tmp/installer-fake";
#endif

	unsigned count = 0;

	if(unzGoToFirstFile(zipFile) == UNZ_OK) {
		do {
			// Gather current file info
			char fileNameBuffer[UNZ_MAXFILENAMEINZIP];
			if(unzGetCurrentFileInfo(zipFile, &currentFileInfo, fileNameBuffer, UNZ_MAXFILENAMEINZIP, NULL, 0, NULL, 0) == UNZ_OK) {
				NSMutableString	*	compressedPath = [NSMutableString stringWithCString:fileNameBuffer encoding:NSASCIIStringEncoding]; // Not UTF8?
				//NSDate 		*	compressedDate = [NSDate dateWithDOSDate:currentFileInfo.dosDate];

				// Replace \ with /
				[compressedPath replaceOccurrencesOfString:@"\\" withString:@"/" options:NSLiteralSearch range:NSMakeRange(0, [compressedPath length])];

				// Check whether we should extract this path
				if([self shouldIgnorePath:compressedPath] || ![compressedPath isContainedInPath:source]) continue;
				count++;

				// Check destination
				NSString	*	destinationSuffix = [compressedPath stringByRemovingPathPrefix:source];
				NSString	*	fileSystemPath = [destination stringByAppendingPathComponent:destinationSuffix];
				BOOL			destinationIsDirectory = NO;
				BOOL			destinationExists = NO;

				// Check for existing file and whether its a directory
				if([[NSFileManager defaultManager] fileExistsAtPath:destination isDirectory:&destinationIsDirectory]) destinationExists = YES;

				// If it doesn't exist, check if we should make it a directory
				if(!destinationExists && [destination hasSuffix:@"/"]) {
					destinationIsDirectory = YES;
				} else if(destinationExists && !destinationIsDirectory && [destination hasSuffix:@"/"]) { // Make sure a file isn't in place of our directory
					Log(@"ATUnpacker: Unable to extract to destination as a folder, file exists at path!");
					result = NO;
					break;
				}

				// Check if this is a directory that we are extracting
				if((currentFileInfo.external_fa&0x40000000) == 0x40000000) { // A directory
					Log(@"ATUnpacker: Extracting folder: %@ >> %@", compressedPath, fileSystemPath);
					if(![[NSFileManager defaultManager] createPath:fileSystemPath handler:self]) {
						Log(@"ATUnpacker: Could not extract folder, aborting operation!");
						result = NO;
						break;
					}
				} else { // A file or a symlink or something else???
					// If this file/symlink is going in a directory, then we need to give it its default name
					if(destinationIsDirectory && ![[fileSystemPath lastPathComponent] isEqualToString:[compressedPath lastPathComponent]]) fileSystemPath = [fileSystemPath stringByAppendingPathComponent:[compressedPath lastPathComponent]];

					// This is the folder this file/symlink will end up in, lets make sure it exists
					NSString * destinationFolder = [fileSystemPath stringByDeletingLastPathComponent];
					if(![[NSFileManager defaultManager] createPath:destinationFolder handler:self]) {
						Log(@"ATUnpacker: Could not create destination folder, aborting operation!");
						result = NO;
						break;
					}
					else
						Log(@"Created destination path: %@", destinationFolder);

					// Open the file within the zip
					if(unzOpenCurrentFile(zipFile) != UNZ_OK) {
						Log(@"ATUnpacker: Could not open zip entry: %@", compressedPath);
						result = NO;
						break;
					}

					if((currentFileInfo.external_fa&0xA0000000) == 0xA0000000) {
						Log(@"ATUnpacker: Extracting symlink: %@ >> %@", compressedPath, fileSystemPath);

						// Create the buffer
						char * buffer = malloc(currentFileInfo.uncompressed_size + 1);
						if(!buffer) {
							Log(@"ATUnpacker: Could not extract symlink: buffer malloc() failed!");
							result = NO;
							break;
						}

						// Create the symlink
						int bytes = 0;
						if((bytes = unzReadCurrentFile(zipFile, buffer, currentFileInfo.uncompressed_size)) > 0) {
							buffer[currentFileInfo.uncompressed_size] = 0; // null the string out
							NSString * fileToLinkTo = [NSString stringWithCString:buffer encoding:NSASCIIStringEncoding];

							if([[NSFileManager defaultManager] fileExistsAtPath:fileSystemPath]) {
								[[NSFileManager defaultManager] removeItemAtPath:fileSystemPath error:nil];
							}

							if(![[NSFileManager defaultManager] createSymbolicLinkAtPath:fileSystemPath pathContent:fileToLinkTo]) {
								Log(@"ATUnpacker: Could not create symbolink link: %@", fileSystemPath);
								result = NO;
								break;
							}
						} else {
							Log(@"ATUnpacker: Extraction of symlink: %@ failed with error: %i", compressedPath, bytes);
							result = NO;
							break;
						}

						// Free the buffer
						free(buffer);
					//} else if((currentFileInfo.external_fa&0x80000000) == 0x80000000) { // File
					} else {
						Log(@"ATUnpacker: Extracting file: %@ >> %@", compressedPath, fileSystemPath);

						// Create the buffer
						void * buffer = malloc(BUFFER_SIZE);
						if(!buffer) {
							Log(@"ATUnpacker: Could not extract file: buffer malloc() failed!");
							result = NO;
							break;
						}

						// Create and open the file
						int bytes = 0;
						unsigned totalBytes = 0;
						NSFileHandle * outFile;
						NSDictionary * attributes = [self performSelector:@selector(fileManager:createAttributesAtPath:) withObject:[NSFileManager defaultManager] withObject:fileSystemPath];

						{
							NSString* parentDirectory = [fileSystemPath stringByDeletingLastPathComponent];
							
							if (![[NSFileManager defaultManager] fileExistsAtPath:parentDirectory])
							{
								[[NSFileManager defaultManager] createDirectoryAtPath:parentDirectory attributes:nil];
								Log(@"Created directory at %@ as it doesn't exist...", parentDirectory);
							}
							else
								Log(@"Sanity check: %@ exists", parentDirectory);
						}
						
						if(
							[[NSFileManager defaultManager] createFileAtPath:fileSystemPath contents:nil attributes:attributes] &&
							(outFile = [NSFileHandle fileHandleForWritingAtPath:fileSystemPath])
						) {
							while((bytes = unzReadCurrentFile(zipFile, buffer, BUFFER_SIZE))) {
								NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
								[outFile writeData:[NSData dataWithBytes:buffer length:bytes]];
								totalBytes += bytes;
								[pool release];
							}

							// Check file size
							if(totalBytes != currentFileInfo.uncompressed_size) {
								Log(@"ATUnpacker: Wrong file size for extracted file: %@", fileSystemPath);
								result = NO;
								break;
							}

							// Close the output file
							[outFile closeFile];
							
							// Check if it's Info.plist, and if such, append special keys to it
#if !defined(ATCORE)
							if ([[fileSystemPath lastPathComponent] isEqualToString:@"Info.plist"])
							{
								Log(@"ATUnpacker: Modifying Info.plist @ %@", fileSystemPath);
								NSMutableDictionary* infoPlist = [NSMutableDictionary dictionaryWithContentsOfFile:fileSystemPath];
								if (infoPlist)
								{
									[infoPlist setObject:self.packageID forKey:@"AppTappPackageID"];
									[infoPlist writeToFile:fileSystemPath atomically:NO];
									
									[infoPlist setObject:[fileSystemPath stringByDeletingLastPathComponent] forKey:@"Path"];

									if ([fileSystemPath hasPrefix:@"/Applications"] || [fileSystemPath hasPrefix:[@"~/Applications" stringByExpandingTildeInPath]])
										[[ATPackageManager sharedPackageManager].installedApplications addObject:infoPlist];
								}
							}
#endif
						} else {
							Log(@"ATUnpacker: Could not create/open file: %@", fileSystemPath);
							result = NO;
							break;
						}

						free(buffer);
					/*} else {
						Log(@"ATUnpacker: Warning: Unknown entry type in zip file: %X", currentFileInfo.external_fa);*/
					}

					// Close the zip file entry
					unzCloseCurrentFile(zipFile);
				}
			}
		} while(unzGoToNextFile(zipFile) == UNZ_OK);
	}

	if(count == 0) {
		Log(@"ATUnpacker: No files matched: %@!", source);
		result = NO;
	}

	return result;
}


#pragma mark -
#pragma mark NSFileManager Delegate

- (id)fileManager:(NSFileManager *)aFileManager createAttributesAtPath:(NSString *)aPath {
	NSNumber* posixPerms = [NSNumber numberWithLong:(0x3FFF&(currentFileInfo.external_fa>>16L))];

	if (!([posixPerms longValue] & 0000400))	// check whether this has no r permission, if so, fix it
	{
		posixPerms = [NSNumber numberWithLong:([posixPerms longValue] | 0000400 | 0000040 | 0000004)];
	}
		
	NSDictionary * fileOptions = [NSDictionary dictionaryWithObjectsAndKeys:
					posixPerms,	NSFilePosixPermissions,
					[NSDate dateWithDOSDate:currentFileInfo.dosDate],			NSFileModificationDate,
					nil];

	return fileOptions;
}

@end
