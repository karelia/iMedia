#import <Cocoa/Cocoa.h>


@interface IMBURLDownload : NSObject {		// similar to NSURLDownload

@private
    NSURLConnection *connection;
	NSFileHandle *handle;
	BOOL deletesFileUponFailure;
	NSString *destination;
	BOOL allowOverwrite;
	NSURLRequest *request;

}

@property (retain, readonly) NSURLRequest *request;
@property (assign) BOOL deletesFileUponFailure;
@property (assign) BOOL allowOverwrite;
@property (copy) NSString *destination;

- (id)initWithRequest:(NSURLRequest *)request delegate:(id)delegate;
- (void)cancel;
- (void)setDestination:(NSString *)path allowOverwrite:(BOOL)allowOverwrite;
- (NSURLRequest *)request;

@end

/*!

@interface NSObject (NSURLDownloadDelegate)

- (void)downloadDidBegin:(NSURLDownload *)download;
- (NSURLRequest *)download:(NSURLDownload *)download willSendRequest:(NSURLRequest *)request redirectResponse:(NSURLResponse *)redirectResponse;
- (void)download:(NSURLDownload *)download didReceiveResponse:(NSURLResponse *)response;
- (void)download:(NSURLDownload *)download didReceiveDataOfLength:(NSUInteger)length;
- (void)download:(NSURLDownload *)download decideDestinationWithSuggestedFilename:(NSString *)filename;
- (void)download:(NSURLDownload *)download didCreateDestination:(NSString *)path;
- (void)downloadDidFinish:(NSURLDownload *)download;
- (void)download:(NSURLDownload *)download didFailWithError:(NSError *)error;

 @end
 
 */







@end
