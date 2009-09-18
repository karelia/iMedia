#import "IMBURLDownload.h"

// Partial replication of NSURLDownload, but one that can be scheduled on another runloop
// (like NSURLConnnection)

@implementation IMBURLDownload

+ (BOOL)canResumeDownloadDecodedWithEncodingMIMEType:(NSString *)MIMEType;
{
	

}


- (id)initWithRequest:(NSURLRequest *)request delegate:(id)delegate;
{
	
	
}



- (id)initWithResumeData:(NSData *)resumeData delegate:(id)delegate path:(NSString *)path;
{
	
	
}



- (void)cancel;
{
	
	
}



- (void)setDestination:(NSString *)path allowOverwrite:(BOOL)allowOverwrite;
{
	
	
}



- (NSURLRequest *)request;
{
	
	
}



- (NSData *)resumeData;
{
	
	
}



- (void)setDeletesFileUponFailure:(BOOL)deletesFileUponFailure;
{
	
	
}



- (BOOL)deletesFileUponFailure;
{
	
	
}






@end
