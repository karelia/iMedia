/*
 iMedia Browser <http://karelia.com/imedia/>
 
 Copyright (c) 2005-2007 by Karelia Software et al.
 
 iMedia Browser is based on code originally developed by Jason Terhorst,
 further developed for Sandvox by Greg Hulands, Dan Wood, and Terrence Talbot.
 Contributions have also been made by Matt Gough, Martin Wennerberg and others
 as indicated in source files.
 
 iMedia Browser is licensed under the following terms:
 
 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in all or substantial portions of the Software without restriction, including
 without limitation the rights to use, copy, modify, merge, publish,
 distribute, sublicense, and/or sell copies of the Software, and to permit
 persons to whom the Software is furnished to do so, subject to the following
 conditions:
 
	Redistributions of source code must retain the original terms stated here,
	including this list of conditions, the disclaimer noted below, and the
	following copyright notice: Copyright (c) 2005-2007 by Karelia Software et al.
 
	Redistributions in binary form must include, in an end-user-visible manner,
	e.g., About window, Acknowledgments window, or similar, either a) the original
	terms stated here, including this list of conditions, the disclaimer noted
	below, and the aforementioned copyright notice, or b) the aforementioned
	copyright notice and a link to karelia.com/imedia.
 
	Neither the name of Karelia Software, nor Sandvox, nor the names of
	contributors to iMedia Browser may be used to endorse or promote products
	derived from the Software without prior and express written permission from
	Karelia Software or individual contributors, as appropriate.
 
 Disclaimer: THE SOFTWARE IS PROVIDED BY THE COPYRIGHT OWNER AND CONTRIBUTORS
 "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT
 LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE,
 AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
 LIABLE FOR ANY CLAIM, DAMAGES, OR OTHER LIABILITY, WHETHER IN AN ACTION OF
 CONTRACT, TORT, OR OTHERWISE, ARISING FROM, OUT OF, OR IN CONNECTION WITH, THE
 SOFTWARE OR THE USE OF, OR OTHER DEALINGS IN, THE SOFTWARE.
 */

#import <QTKit/QTKit.h>
#import "QTMovie+iMedia.h"
#import "MetadataTool.h"
#import "MetadataUtility.h"

@protocol MetadataUtilityProtocol

- (NSDictionary *)getMetadataForFileThroughConnection:(oneway NSString *)file;

@end

@implementation MetadataUtility

// This thread handles all the communication with the MetadataTool. It is necessary because NSConnections are only
// valid for the thread they are created on.
- (void)run
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    
    [myLock lock];
    myServerIdentifier = [[[NSProcessInfo processInfo] globallyUniqueString] retain];
    
    myServerTask = [[NSTask alloc] init];
    [myServerTask setLaunchPath:[[NSBundle bundleForClass:[self class]] pathForResource:@"MetadataTool" ofType:NULL]];
    [myServerTask setArguments:[NSArray arrayWithObjects:myServerIdentifier, [[NSNumber numberWithInt:[[NSProcessInfo processInfo] processIdentifier]] stringValue], NULL]];
    [myServerTask setStandardOutput:[NSFileHandle fileHandleWithStandardOutput]];
    [myServerTask launch];
    
    // now make the connection
    NSDate *start_date = [NSDate date];
    while ( myServerProxy == nil && [[NSDate date] timeIntervalSinceDate:start_date] < 10.0 )
    {
        [NSThread sleepUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
        myServerProxy = [[NSConnection rootProxyForConnectionWithRegisteredName:myServerIdentifier host:nil] retain];
    }
    
    if ( myServerProxy != nil )
    {
        [myServerProxy setProtocolForProxy:@protocol(MetadataToolProtocol)];
    }
    
    [myLock unlockWithCondition:1];
    
    NSConnection *connection = [NSConnection defaultConnection];
    
    [connection setRootObject:self];
    
    if ( [connection registerName:@"MetadataUtility"] == YES )
    {
        [[NSRunLoop currentRunLoop] run];
    }
    
    [pool release];
}

- (id)init
{
    self = [super init];
    if (self)
    {
        // a lock for ensuring that we're fully initialized before returning. it is only
        // used here but must be an instance variable because it needs to be set in the run thread.
        myLock = [[NSConditionLock alloc] initWithCondition:0];
        
        [NSThread detachNewThreadSelector:@selector(run) toTarget:self withObject:NULL];
        
        [myLock lockWhenCondition:1];
    }
    return self;
}

- (void)dealloc
{
    [myServerIdentifier release]; myServerIdentifier = nil;
    [myServerTask release]; myServerTask = nil;
    [myServerProxy release]; myServerProxy = nil;
    
    [myLock release]; myLock = nil;
    
    [super dealloc];
}

static MetadataUtility *theMetadataUtility = nil;

+ (MetadataUtility *)sharedMetadataUtility
{
    // this needs to be synchronized so that we only create one instance of the metadata utility.
    @synchronized ([self class])
    {
        if (!theMetadataUtility)
        {
            theMetadataUtility = [[MetadataUtility alloc] init];
        }
    }
    return theMetadataUtility;
}

// this version of the function is used to run on the main thread, just in case our metadata tool cannot be configured.
- (void)getMetadataWithArguments:(NSMutableDictionary *)arguments
{
    NSString *file = [arguments objectForKey:@"file"];
    
    NSError *error = nil;
    QTMovie *movie = [[QTMovie alloc] initWithFile:file error:&error];
    
    if ( movie != nil && error == nil )
    {
        [arguments setValue:[NSArray arrayWithObject:@"Sound"] forKey:@"kMDItemMediaTypes"];
        
        [arguments setValue:[NSNumber numberWithFloat:[movie durationInSeconds]] forKey:@"kMDItemDurationSeconds"];
        
        // Get the meta data from the QTMovie
        NSString *name = [movie attributeWithFourCharCode:kUserDataTextFullName];
        if (name)
        {
            [arguments setObject:name forKey:@"kMDItemTitle"];
        }
        
        NSString *artist = [movie attributeWithFourCharCode:kUserDataTextArtist];
        if (artist)
        {
            [arguments setObject:[NSArray arrayWithObject:artist] forKey:@"kMDItemAuthors"];
        }
        
        if ([movie isDRMProtected])
        {
            [arguments setObject:@"Protected" forKey:@"kMDItemKind"];
        }
        
        [movie release];
    }
}

// this method should only be called via a connection (to ourself). used to make sure all calls
// to the metadata tool process all come from a single thread.
- (NSDictionary *)getMetadataForFileThroughConnection:(oneway NSString *)file
{
    return [myServerProxy getMetadataForFile:file];
}

/*
 * Return a dictionary representing the metadata for the given music file.
 *
 * The dictionary should contain the following keys:
 *      kMDItemMediaTypes       (NSArray of NSStrings)
 *      kMDItemTitle            (NSString)
 *      kMDItemDurationSeconds  (NSNumber)
 *      kMDItemAuthors          (NSArray of NSStrings)
 *      kMDItemKind             (NSString, will contain the string 'protected' if DRM protected)
 *
 * First try the fastest way: spotlight metadata.
 * Next try the metadata tool process.
 * Finally try to get the metadata from the main thread.
 */
- (NSDictionary *)getMetadataForFile:(NSString *)file
{
    MDItemRef item = MDItemCreate(kCFAllocatorDefault, (CFStringRef)file);
    
    NSArray *attributeNames = [NSArray arrayWithObjects:@"kMDItemMediaTypes", @"kMDItemTitle", @"kMDItemDurationSeconds", @"kMDItemAuthors", @"kMDItemKind", nil];
    
    CFDictionaryRef attributes_cf = MDItemCopyAttributes(item,(CFArrayRef)attributeNames);

    NSDictionary *attributes = [NSDictionary dictionaryWithDictionary:(NSDictionary *)attributes_cf];

    CFRelease(attributes_cf);

    CFRelease(item);
    
    NSArray *mediaTypes = [attributes objectForKey:@"kMDItemMediaTypes"];
    if ( mediaTypes != nil && [mediaTypes containsObject:@"Sound"] )
    {
        // spotlight worked! return the attributes.
        
        return attributes;
    }
    else if ( myServerProxy != nil )
    {
        // all calls to metadata tool must come from the same thread. so send our message off to our
        // MetadataUtility thread!
        
        id proxy = [NSConnection rootProxyForConnectionWithRegisteredName:@"MetadataUtility" host:nil];
        
        [proxy setProtocolForProxy:@protocol(MetadataUtilityProtocol)];
        
        NSDictionary *attributes = [proxy getMetadataForFileThroughConnection:file];
        
        return attributes;
    }
    else
    {
        // nothing else has worked. ask the main thread to read the metadata.
        
        NSMutableDictionary *arguments = [NSMutableDictionary dictionaryWithObject:file forKey:@"file"];
        
        [self performSelectorOnMainThread:@selector(getMetadataWithArguments:) withObject:arguments waitUntilDone:YES];
        
        NSArray *mediaTypes = [attributes objectForKey:@"kMDItemMediaTypes"];
        if ( mediaTypes != nil && [mediaTypes containsObject:@"Sound"] )
        {
            return [NSDictionary dictionaryWithDictionary:arguments];
        }
        
        return nil;
    }
}

@end
