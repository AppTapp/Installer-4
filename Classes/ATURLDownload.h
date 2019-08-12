//
//  ATURLDownload.h
//  Installer
//
//  Created by Slava Karpenko on 7/10/08.
//  Copyright 2008 RiP Dev. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <curl/curl.h>

@interface ATURLDownload : NSObject {
	//NSURLConnection*	connection;
	CURL*				curl;
	NSFileHandle*		downloadFile;
	NSString*			downloadFilePath;
	id					delegate;
	NSURL*				url;
	BOOL				cancel;
    NSString*           userAgent;
	
	void*				refcon;
}

@property (retain) NSFileHandle* downloadFile;
@property (retain) NSString* downloadFilePath;
@property (nonatomic, assign) id delegate;
@property (retain) NSURL* url;
@property (assign) BOOL cancel;
@property (assign) void* refcon;

- (id)initWithRequest:(NSURLRequest *)request delegate:(id)del;
- (id)initWithRequest:(NSURLRequest *)request delegate:(id)del userAgent:(NSString*)agent;
- (id)initWithRequest:(NSURLRequest *)request delegate:(id)del resumeable:(BOOL)resumeable;
- (id)initWithRequest:(NSURLRequest *)request delegate:(id)del resumeable:(BOOL)resumeable userAgent:(NSString*)agent;

- (void)cancelDownload;			// you will be called a download:didFailWithError: when the actual abort is done.

@end

@interface NSObject (ATURLDownloadDelegate)

/*!
    @method downloadDidBegin:
    @abstract This method is called immediately after the download has started.
    @param download The download that just started downloading.
*/
- (void)downloadDidBegin:(ATURLDownload *)download;

/*!
    @method download:didReceiveDataOfLength:
    @abstract This method is called when the download has loaded data.
    @param download The download that has received data.
    @param length The length of the received data.
    @discussion This method will be called one or more times.
*/
- (void)download:(ATURLDownload *)download didReceiveDataOfLength:(NSUInteger)length;

/*!
    @method download:didCreateDestination:
    @abstract This method is called after the download creates the downloaded file.
    @param download The download that created the downloaded file.
    @param path The path of the downloaded file.
*/
- (void)download:(ATURLDownload *)download didCreateDestination:(NSString *)path;

/*!
    @method downloadDidFinish:
    @abstract This method is called when the download has finished downloading.
    @param download The download that has finished downloading.
    @discussion This method is called after all the data has been received and written to disk.
    This method or download:didFailWithError: will only be called once.
*/
- (void)downloadDidFinish:(ATURLDownload *)download;

/*!
    @method download:didFailWithError:
    @abstract This method is called when the download has failed. 
    @param download The download that ended in error.
    @param error The error caused the download to fail.
    @discussion This method is called when the download encounters a network or file I/O related error.
    This method or downloadDidFinish: will only be called once.
*/
- (void)download:(ATURLDownload *)download didFailWithError:(NSError *)error;

@end
