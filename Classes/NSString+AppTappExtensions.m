// AppTapp Framework
// Copyright 2007 Nullriver, Inc.

#import "NSString+AppTappExtensions.h"
#import "md5.h"

#define DEVELOPMENT_STAGE 0x20
#define ALPHA_STAGE 0x40
#define BETA_STAGE 0x60
#define RELEASE_STAGE 0x80

// 12345678901234567890
// 10.10.20b13-777
#define MAX_VERS_LEN 15

#define _isDigit(aChar) (((aChar >= (UniChar)'0') && (aChar <= (UniChar)'9')) ? YES : NO)

@implementation NSString (AppTappExtensions)

- (NSString *)MD5Hash
{
	if ([self length])
	{
		MD5_CTX ctx;
		unsigned char digest[16];
		
		MD5Init(&ctx);
		
		MD5Update(&ctx, [self UTF8String], [self lengthOfBytesUsingEncoding:NSUTF8StringEncoding]);
		
		MD5Final(digest, &ctx);
		
		char hexdigest[33];
		int a;
		
		for (a = 0; a < 16; a++) sprintf(hexdigest + 2*a, "%02x", digest[a]);
		
		return [NSString stringWithCString:hexdigest];
	}
	else
		return nil;
}

- (NSString *)stringByRemovingPathPrefix:(NSString *)pathPrefix {
	if([pathPrefix isEqualToString:@"."]) return self;

	if([self hasPrefix:pathPrefix]) {
		NSMutableString * result = [NSMutableString stringWithString:self];

		return [result substringFromIndex:[pathPrefix length]];
	} else {
		return self;
	}
}

- (BOOL)isContainedInPath:(NSString *)aPath {
	aPath = [aPath stringByStandardizingPath];

	if([aPath isEqualToString:@"."]) return YES;
	
	NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
	
	NSArray * components = [self pathComponents];
	NSEnumerator * allComponents = [[aPath pathComponents] objectEnumerator];
	NSString * component;

	unsigned index = 0;
	while(index < [components count] && (component = [allComponents nextObject])) {
		if(![[components objectAtIndex:index] isEqualToString:component]) {
			
			[pool release];
			return NO;
		}
		index++;
	}
	
	[pool release];

	return YES;
}

- (NSString *)stringByExpandingSpecialPathsInPath {
	NSString * result = nil;
	
	if ([self hasPrefix:@"~"])
	{
		if ([self length] > 1)
			result = [NSString stringWithFormat:@"/var/mobile%@", [self substringFromIndex:1]];
		else
			result = @"/var/mobile";
	}
	else
		result = self;

	if([result hasPrefix:@"@Applications"]) {
		result = [[ATPlatform applicationsPath] stringByAppendingPathComponent:[result substringFromIndex:[@"@Applications" length]]];
	}

	return result;
}

- (NSString*)sqliteEscapedString
{
    NSMutableString* string = nil;
    
    string = [NSMutableString stringWithString:self];
    [string replaceOccurrencesOfString:@"'"
                            withString:@"''"
                               options:0
                                 range:NSMakeRange( 0, [string length] )];
    
    return string;
}

#pragma mark -
#pragma mark Stolen from CF

- (unsigned long long)versionNumber
{
    // Parse version number from string.
    // String can begin with "." for major version number 0.  String can end at any point, but elements within the string cannot be skipped.
    unsigned long long major1 = 0, major2 = 0, minor1 = 0, minor2 = 0, minor1_2 = 0, minor2_2 = 0, stage = RELEASE_STAGE, build = 0, revision = 0;
    UniChar versChars[MAX_VERS_LEN];
    UniChar *chars = NULL;
    CFIndex len;
    unsigned long long theVers;
    BOOL digitsDone = NO;

    if (![self length]) return 0;

    len = [self length];

    if ((len == 0) || (len > MAX_VERS_LEN)) return 0;

	[self getCharacters:versChars];
    chars = versChars;
    
    // Get major version number.
    major1 = major2 = 0;
    if (_isDigit(*chars)) {
        major2 = *chars - (UniChar)'0';
        chars++;
        len--;
        if (len > 0) {
            if (_isDigit(*chars)) {
                major1 = major2;
                major2 = *chars - (UniChar)'0';
                chars++;
                len--;
                if (len > 0) {
                    if (*chars == (UniChar)'.') {
                        chars++;
                        len--;
                    } else {
                        digitsDone = true;
                    }
                }
            } else if (*chars == (UniChar)'.') {
                chars++;
                len--;
            } else {
                digitsDone = true;
            }
        }
    } else if (*chars == (UniChar)'.') {
        chars++;
        len--;
    } else {
        digitsDone = true;
    }

    // Now major1 and major2 contain first and second digit of the major version number as ints.
    // Now either len is 0 or chars points at the first char beyond the first decimal point.

    // Get the first minor version number.
	if (len > 0 && !digitsDone)
	{
		if (_isDigit(*chars)) {
			minor1_2 = *chars - (UniChar)'0';
			chars++;
			len--;
			if (len > 0) {
				if (_isDigit(*chars)) {
					minor1 = minor1_2;
					minor1_2 = *chars - (UniChar)'0';
					chars++;
					len--;
					if (len > 0) {
						if (*chars == (UniChar)'.') {
							chars++;
							len--;
						} else {
							digitsDone = true;
						}
					}
				} else if (*chars == (UniChar)'.') {
					chars++;
					len--;
				} else {
					digitsDone = true;
				}
			}
		} else if (*chars == (UniChar)'.') {
			chars++;
			len--;
		} else {
			digitsDone = true;
		}
	}

    // Now minor1 contains the first minor version number as an int.
    // Now either len is 0 or chars points at the first char beyond the second decimal point.

    // Get the second minor version number. 
	if (len > 0 && !digitsDone)
	{
		if (_isDigit(*chars)) {
			minor2_2 = *chars - (UniChar)'0';
			chars++;
			len--;
			if (len > 0) {
				if (_isDigit(*chars)) {
					minor2 = minor2_2;
					minor2_2 = *chars - (UniChar)'0';
					chars++;
					len--;
					if (len > 0) {
						digitsDone = true;
					}
				} else {
					digitsDone = true;
				}
			}
		} else {
			digitsDone = true;
		}
	}

    // Now minor2 contains the second minor version number as an int.
    // Now either len is 0 or chars points at the build stage letter.

    // Get the build stage letter.  We must find 'd', 'a', 'b', or 'f' next, if there is anything next.
    if (len > 0) {
        if (*chars == (UniChar)'d') {
            stage = DEVELOPMENT_STAGE;
        } else if (*chars == (UniChar)'a') {
            stage = ALPHA_STAGE;
        } else if (*chars == (UniChar)'b') {
            stage = BETA_STAGE;
        } else if (*chars == (UniChar)'f') {
            stage = RELEASE_STAGE;
        } else if (*chars == (UniChar)'v') {
            stage = RELEASE_STAGE;
        } else if (*chars == (UniChar)'-') {
			chars--;
			len++;
		} else {
            return 0;
        }
        chars++;
        len--;
    }

    // Now stage contains the release stage.
    // Now either len is 0 or chars points at the build number.

    // Get the first digit of the build number.
    if (len > 0) {
        if (_isDigit(*chars)) {
            build = *chars - (UniChar)'0';
            chars++;
            len--;
        } else {
			if (*chars != (UniChar)'-')
				return 0;
        }
    }
    // Get the second digit of the build number.
    if (len > 0) {
        if (_isDigit(*chars)) {
            build *= 10;
            build += *chars - (UniChar)'0';
            chars++;
            len--;
        } else {
			if (*chars != (UniChar)'-')
				return 0;
        }
    }
	
    // Get the third digit of the build number.
    if (len > 0) {
        if (_isDigit(*chars)) {
            build *= 10;
            build += *chars - (UniChar)'0';
            chars++;
            len--;
        } else {
			if (*chars != (UniChar)'-')
				return 0;
        }
    }
	
	// Check for revision number
	if (len > 0 && (*chars == (UniChar)'-'))
	{
		len--;
		chars++;
		
		if (len > 0)
		{
			if (_isDigit(*chars))
			{
				revision = *chars - (UniChar)'0';
				chars++;
				len--;
			}
			else
				return 0;
			
			// Get the second digit of the revision
			if (len > 0)
			{
				if (_isDigit(*chars)) {
					revision *= 10;
					revision += *chars - (UniChar)'0';
					chars++;
					len--;
				} else
					return 0;
			
				// And get the third digit of the revision
				if (len > 0)
				{
					if (_isDigit(*chars)) {
						revision *= 10;
						revision += *chars - (UniChar)'0';
						chars++;
						len--;
					} else
						return 0;
				}
			}
			
		}
	}
	
    // Range check the build number and make sure we exhausted the string.
    if ((build > 0xFF) || (revision > 0xFF) || (len > 0)) return 0;

    // Build the number
    theVers = major1 << 44;
    theVers += major2 << 40;
    theVers += minor1 << 36;
	theVers += minor1_2 << 32;
    theVers += minor2 << 28;
	theVers += minor2_2 << 24;
    theVers += stage << 16;
    theVers += build << 8;
	theVers += revision;

	//Log(@"%@ vers = 0x%08X%08X", self, (UInt32)((theVers >> 32) & 0xFFFFFFFF), (UInt32)((theVers) & 0xFFFFFFFF));

    return theVers;
}

@end
