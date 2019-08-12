//
//  ATURLDownload.m
//  Installer
//
//  Created by Slava Karpenko on 7/10/08.
//  Copyright 2008 RiP Dev. All rights reserved.
//

#import "ATURLDownload.h"
#import "ATPlatform.h"
#import "NSFileManager+AppTappExtensions.h"
#import "ATPackageManager.h"
#import "ATIncompleteDownload.h"
#import "ATIncompleteDownloads.h"
#import "NSURL+AppTappExtensions.h"
#import <CoreFoundation/CoreFoundation.h>
#import <SystemConfiguration/SystemConfiguration.h>

#ifdef INSTALLER_APP
    #import "IAPhoneManager.h"
#else
    #import <CFNetwork/CFProxySupport.h>
#endif // INSTALLER_APP

#define kATURLDownloadTimeout		600			// 10 minutes oughtta be enough for everybody...‚Ñ¢

static size_t _curl_write(void *buffer, size_t size, size_t nmemb, void *userp);

@implementation ATURLDownload

@synthesize downloadFile;
@synthesize downloadFilePath;
@synthesize delegate;
@synthesize url;
@synthesize cancel;
@synthesize refcon;

- (id)initWithRequest:(NSURLRequest *)request delegate:(id)del
{
	return [self initWithRequest:request delegate:del resumeable:NO userAgent:nil];
}

- (id)initWithRequest:(NSURLRequest *)request delegate:(id)del userAgent:(NSString*)agent
{
	return [self initWithRequest:request delegate:del resumeable:NO userAgent:agent];
}

- (id)initWithRequest:(NSURLRequest *)request delegate:(id)del resumeable:(BOOL)resumeable
{
	return [self initWithRequest:request delegate:del resumeable:resumeable userAgent:nil];
}

- (id)initWithRequest:(NSURLRequest *)request delegate:(id)del resumeable:(BOOL)resumeable userAgent:(NSString*)agent
{
	if (self = [super init])
	{
        userAgent = [agent copy];

		cancel = NO;
		self.delegate = del;
		
		self.url = [request URL];
		
		if ([self.url isFileURL])
		{
			// woot
			self.downloadFilePath = [[NSFileManager defaultManager] tempFilePath];
			if ([delegate respondsToSelector:@selector(downloadDidBegin:)])
				[delegate downloadDidBegin:self];
			if ([delegate respondsToSelector:@selector(download:didCreateDestination:)])
				[delegate download:self didCreateDestination:self.downloadFilePath];
			
			if ([[NSFileManager defaultManager] copyItemAtPath:[url path] toPath:self.downloadFilePath error:nil])
			{
				[self connectionDidFinishLoading:nil];
			}
			else
			{
				[self connection:nil didFailWithError:[NSError errorWithDomain:CURLErrorDomain code:CURLE_FILE_COULDNT_READ_FILE userInfo:nil]];
			}
			
			return self;
		}
		
		curl = curl_easy_init();
		
		if (resumeable)
		{
			// find whether this file was attempted download before
			ATIncompleteDownload* dl = [[ATPackageManager sharedPackageManager].incompleteDownloads downloadWithLocation:[request URL]];
			if (dl)
			{
				self.downloadFilePath = [__DOWNLOADS_PATH__ stringByAppendingPathComponent:dl.path];
			}
			else
			{
				NSString* tempFileName = [[request URL] tempDownloadFileName];
				
				self.downloadFilePath = [__DOWNLOADS_PATH__ stringByAppendingPathComponent:tempFileName];
				
				dl = [[ATIncompleteDownload alloc] init];
				
				dl.url = [request URL];
				dl.path = tempFileName;
				dl.date = [NSDate date];
				
				[dl commit];

				[dl release];
			}
		}
		else
			self.downloadFilePath = [[NSFileManager defaultManager] tempFilePath];
		
		if ([delegate respondsToSelector:@selector(downloadDidBegin:)])
			[delegate downloadDidBegin:self];

		if([[NSFileManager defaultManager] fileExistsAtPath:self.downloadFilePath] || [[NSFileManager defaultManager] createFileAtPath:self.downloadFilePath contents:nil attributes:nil])
		{
			self.downloadFile = [NSFileHandle fileHandleForWritingAtPath:self.downloadFilePath];
			
			[self.downloadFile seekToEndOfFile];
			
			if ([delegate respondsToSelector:@selector(download:didCreateDestination:)])
				[delegate download:self didCreateDestination:self.downloadFilePath];
		}

		if (curl)
		{
			curl_easy_setopt(curl, CURLOPT_URL, [[[request URL] absoluteString] UTF8String]);
			curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, &_curl_write);
			curl_easy_setopt(curl, CURLOPT_WRITEDATA, self);
			curl_easy_setopt(curl, CURLOPT_FOLLOWLOCATION, 1);
			curl_easy_setopt(curl, CURLOPT_NOSIGNAL, 1);
			curl_easy_setopt(curl, CURLOPT_CONNECTTIMEOUT, 15); // 15 seconds connect timeout
			curl_easy_setopt(curl, CURLOPT_TIMEOUT, kATURLDownloadTimeout); // 30 seconds overall timeout

#if !defined(__i386__)
			CFDictionaryRef	proxySettings = CFNetworkCopySystemProxySettings();
			
			if (proxySettings)
			{
				CFNumberRef isProxyEnabled = (CFNumberRef)CFDictionaryGetValue(proxySettings, kCFNetworkProxiesHTTPEnable);
				CFStringRef proxyName = (CFStringRef)CFDictionaryGetValue(proxySettings, kCFNetworkProxiesHTTPProxy);
				CFNumberRef proxyPort = (CFNumberRef)CFDictionaryGetValue(proxySettings, kCFNetworkProxiesHTTPPort);
				
				if (isProxyEnabled && [(NSNumber*)isProxyEnabled intValue] && proxyPort && proxyName)
				{
					curl_easy_setopt(curl, CURLOPT_PROXY, [(NSString*)proxyName UTF8String]);
					curl_easy_setopt(curl, CURLOPT_PROXYPORT, [(NSNumber*)proxyPort unsignedIntValue]);
				}
				
				CFRelease(proxySettings);
			}
#elif defined(INSTALLER_APP)
            CFDictionaryRef	proxySettings = SCDynamicStoreCopyProxies(NULL);            

            if (proxySettings != NULL)
            {
                CFNumberRef isProxyEnabledNumber = (CFNumberRef)CFDictionaryGetValue(proxySettings, kSCPropNetProxiesHTTPEnable);
                NSInteger isProxyEnabled = 0;
    
                if (isProxyEnabledNumber != NULL && CFGetTypeID(isProxyEnabledNumber) == CFNumberGetTypeID())
                    CFNumberGetValue(isProxyEnabledNumber, kCFNumberIntType, &isProxyEnabled);

                if (isProxyEnabled)
                {
                    CFStringRef proxyName = (CFStringRef)CFDictionaryGetValue(proxySettings, kSCPropNetProxiesHTTPProxy);
                    CFNumberRef proxyPortNumber = (CFNumberRef)CFDictionaryGetValue(proxySettings, kSCPropNetProxiesHTTPPort);
                    NSInteger proxyPort = 0;

                    if (proxyPortNumber != NULL && CFGetTypeID(proxyPortNumber) == CFNumberGetTypeID())
                        CFNumberGetValue(proxyPortNumber, kCFNumberIntType, &proxyPort);

                    if (proxyName != NULL && proxyPort > 0)
                    {
                        curl_easy_setopt(curl, CURLOPT_PROXY, [(NSString*)proxyName UTF8String]);
                        curl_easy_setopt(curl, CURLOPT_PROXYPORT, proxyPort);
                    }
                }
				
				CFRelease(proxySettings);
            }
#endif // __i386__ & INSTALLER_APP

			if ([[NSFileManager defaultManager] fileExistsAtPath:self.downloadFilePath])
			{
				unsigned long long fs = [[[NSFileManager defaultManager] fileAttributesAtPath:self.downloadFilePath traverseLink:NO] fileSize];
				if (fs > 0)
				{
					curl_off_t offset = fs;
					
					curl_easy_setopt(curl, CURLOPT_RESUME_FROM_LARGE, offset);
				}
			}
		
			[self performSelector:@selector(start) withObject:nil afterDelay:0.];
		}
		
	}
	
	return self;
}

- (void)start
{
	CURLcode res = CURLE_FAILED_INIT;
	[self retain];
	
	if (curl)
    {
        if (userAgent != nil)
            curl_easy_setopt(curl, CURLOPT_USERAGENT, [userAgent UTF8String]);
        else
            curl_easy_setopt(curl, CURLOPT_USERAGENT, [__USER_AGENT__ UTF8String]);

#ifdef INSTALLER_APP
		// Add saurik's extended http fields.
		struct curl_slist* headers = NULL;
		
        NSString* deviceUUID = [[IAPhoneManager sharedPhoneManager] fakeDeviceIdentifier];
		if (deviceUUID != nil)
			headers = curl_slist_append(headers, [[NSString stringWithFormat:@"X-Unique-ID: %@", deviceUUID] UTF8String]);

        NSString* version = [[IAPhoneManager sharedPhoneManager] fakeSystemVersion];
        if (version != nil)
            headers = curl_slist_append(headers, [[NSString stringWithFormat:@"X-Firmware: %@", version] UTF8String]);

		// Machine name.
        NSString* machineName = [[IAPhoneManager sharedPhoneManager] fakeMachineName];
        if (machineName != nil)
			headers = curl_slist_append(headers, [[NSString stringWithFormat:@"X-Machine: %@", machineName] UTF8String]);

        if (headers != NULL)
            curl_easy_setopt(curl, CURLOPT_HTTPHEADER, headers);

		res = curl_easy_perform(curl);

        if (headers != NULL)
            curl_slist_free_all(headers);
#else
		res = curl_easy_perform(curl);
#endif // INSTALLER_APP
    }

	if (res != CURLE_OK)
	{
		NSError* err = nil;
		NSDictionary* userInfo = nil;
		
		const char* errStr = curl_easy_strerror(res);
		
		if (errStr)
		{
			NSString* fullError = [NSString stringWithFormat:@"%@ (%@)", [NSString stringWithUTF8String:errStr], [self.url host]];
		
			userInfo = [NSDictionary dictionaryWithObjectsAndKeys:fullError, NSLocalizedDescriptionKey, nil];
		}
		
		err = [NSError errorWithDomain:CURLErrorDomain code:res userInfo:userInfo];
		
		[self connection:nil didFailWithError:err];
	}
	
	if (res == CURLE_OK ||
		res == CURLE_WRITE_ERROR)		// write error = manual abort, no need to keep the file around
	{
		// remove incomplete download (as it's now complete)
		ATIncompleteDownload* dl = [[ATPackageManager sharedPackageManager].incompleteDownloads downloadWithLocation:self.url];
		if (dl)
		{
			[dl remove];
		}
		
		[self connectionDidFinishLoading:nil];
	}
	
	[self release];
}

- (void)dealloc
{
	if (curl)
		curl_easy_cleanup(curl);
	
	[self.downloadFile closeFile];
	self.downloadFile = nil;
	self.downloadFilePath = nil;
	
	self.url = nil;
	
    [userAgent release];

	[super dealloc];
}

- (void)cancelDownload
{
	cancel = YES;
}

#pragma mark -
#pragma mark NSURL Download Delegate

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)newBytes {
	[self.downloadFile writeData:newBytes];

	if ([self.delegate respondsToSelector:@selector(download:didReceiveDataOfLength:)])
		[self.delegate download:self didReceiveDataOfLength:[newBytes length]];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
	[self.downloadFile closeFile];
	self.downloadFile = nil;
	
	if ([self.delegate respondsToSelector:@selector(downloadDidFinish:)])
		[self.delegate downloadDidFinish:self];
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)failReason {
	if ([self.delegate respondsToSelector:@selector(download:didFailWithError:)])
		[self.delegate download:self didFailWithError:failReason];
}

@end

static size_t _curl_write(void *buffer, size_t size, size_t nmemb, void *userp)
{
	ATURLDownload* dl = (ATURLDownload*)userp;

	if (dl.cancel)
		return -1;

	NSData* newData = [[NSData alloc] initWithBytesNoCopy:buffer length:(size*nmemb) freeWhenDone:NO];
	//Log(@"curl_write_data: %@ <- size: %d", dl, size*nmemb);
	[dl connection:nil didReceiveData:newData];
	[newData release];
	
	return size*nmemb;
}
