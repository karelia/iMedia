//
//  NSBundle+iMedia.m
//  iMedia
//
//  Created by Jörg Jacobsen on 26.11.12.
//
//

#import <Quartz/Quartz.h>
#import "NSBundle+iMedia.h"
#import "NSObject+iMedia.h"

@implementation NSBundle (iMedia)

// Returns the XPC service bundle with inIdentifier contained inside of this bundle
// Returns nil if this bundle does not contain such XPC service bundle
//
- (NSBundle *) XPCServiceBundleWithIdentifier:(NSString *)inIdentifier
{
    NSURL *servicesDirURL = [[self bundleURL] URLByAppendingPathComponent:@"Contents/XPCServices" isDirectory:YES];
    NSString *serviceDirName = [inIdentifier stringByAppendingPathExtension:@"xpc"];
    NSURL *serviceURL = [servicesDirURL URLByAppendingPathComponent:serviceDirName];
    NSBundle *serviceBundle = nil;
    
    if (serviceURL) {
        serviceBundle = [NSBundle bundleWithURL:serviceURL];
    }
    return serviceBundle;
}

// Returns whether this bundle supports execution of an XPC service identified by inIdentifier.
// Note that "support" comprises two requirements:
// 1. Bundle contains an XPC service bundle of given identifier
// 2. App currently runs on an OS version supporting XPC services
//
- (BOOL) supportsXPCServiceWithIdentifier:(NSString *)inIdentifier
{
	BOOL supportsService = NO;

    // Bundle does not legitimately provide an XPC service if the OS is not XPC Service-ready
    if (NSAppKitVersionNumber >= 1138) // Are we running on Lion?
    {
        if ([self XPCServiceBundleWithIdentifier:inIdentifier]) {
            supportsService = YES;
        }
    }
	return supportsService;
}

//
//
- (id) imb_imageRepresentationForImageNamed:(NSString*)inName representationType:(NSString*)inRepresentationType
{
	id image = nil;
	static NSMutableDictionary* sImageCache;
	static dispatch_once_t sOnceToken;
	
	dispatch_once(&sOnceToken,^()
                  {
                      sImageCache = [[NSMutableDictionary alloc] init];
                  });
	
	@synchronized(sImageCache)
	{
		image = [sImageCache objectForKey:inName];
		
		if (image == nil)
		{
            NSURL *URL = [self URLForResource:inName withExtension:nil];
            if (URL) {
                if ([inRepresentationType isEqualToString:IKImageBrowserNSDataRepresentationType]) {
                    image = [NSData dataWithContentsOfURL:URL];
                } else if ([inRepresentationType isEqualToString:IKImageBrowserNSImageRepresentationType]) {
                    image = [[[NSImage alloc] initWithContentsOfURL:URL] autorelease];
                } else /* if ([inRepresentationType isEqualToString:IKImageBrowserCGImageRepresentationType]) {
                    CGImageSourceRef source = CGImageSourceCreateWithURL((CFURLRef)URL,NULL);
                    image = (id)CGImageSourceCreateImageAtIndex(source,0,NULL);
                } else */{
                    NSString *errorReason = [NSString stringWithFormat:
                                             @"%@ does not (yet) support image representation type: %@",
                                             NSStringFromSelector(_cmd), inRepresentationType];
                    [self imb_throwProgrammerErrorExceptionWithReason:errorReason];
                }
            }
			if (image) [sImageCache setObject:image forKey:inName];
		}
	}
	
	return image;
}

@end
