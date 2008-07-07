/*
 iMedia Browser Framework <http://karelia.com/imedia/>
 
 Copyright (c) 2005-2008 by Karelia Software et al.
 
 iMedia Browser is based on code originally developed by Jason Terhorst,
 further developed for Sandvox by Greg Hulands, Dan Wood, and Terrence Talbot.
 Contributions have also been made by Matt Gough, Martin Wennerberg and others
 as indicated in source files.
 
 The iMedia Browser Framework is licensed under the following terms:
 
 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in all or substantial portions of the Software without restriction, including
 without limitation the rights to use, copy, modify, merge, publish,
 distribute, sublicense, and/or sell copies of the Software, and to permit
 persons to whom the Software is furnished to do so, subject to the following
 conditions:
 
	Redistributions of source code must retain the original terms stated here,
	including this list of conditions, the disclaimer noted below, and the
	following copyright notice: Copyright (c) 2005-2008 by Karelia Software et al.
 
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

/*
 * This code original written by Chris Meyer, LQ Graphics, Inc.
 *
 * It waits for calls to get the metadata for a particular file, then fills
 * in the dictionary attributes. If the parent process dies for some reason,
 * this process exits automatically.
 */

#import <Foundation/Foundation.h>
#import <QTKit/QTKit.h>
#import "QTMovie+iMedia.h"
#import "MetadataTool.h"

@implementation MainThread

- (id)initWithServerIdentifier:(NSString *)serverIdentifier parentProcessIdentifier:(int)parentProcessIdentifier
{
    self = [super init];
    if ( self != NULL )
    {
        myServerIdentifier = [serverIdentifier retain];
        myParentProcessIdentifier = parentProcessIdentifier;
    }
    return self;
}

- (void)dealloc
{
    [super dealloc];
}

- (BOOL)isParentProcessStillAlive
{
    NSArray *applications = [[NSWorkspace sharedWorkspace] launchedApplications];
    NSEnumerator *enumerator = [applications objectEnumerator];
    NSDictionary *application_info;
    while ( (application_info = [enumerator nextObject]) != NULL )
    {
        NSNumber *process_identifier_number = [application_info objectForKey:@"NSApplicationProcessIdentifier"];
        if ( process_identifier_number != NULL && [process_identifier_number intValue] == myParentProcessIdentifier )
            return YES;
    }
    return NO;
}

- (void)run
{
    NSConnection *connection = [NSConnection defaultConnection];
    
    [connection setRootObject:self];
    
    if ( [connection registerName:myServerIdentifier] == YES )
    {
        NSRunLoop *run_loop = [NSRunLoop currentRunLoop];
        
        BOOL result = YES;
        BOOL is_parent_process_alive = YES;
        
        do
        {
            NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
            
            result = [run_loop runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.5]];

            is_parent_process_alive = [self isParentProcessStillAlive];
            
            [pool release];
        }
        while (is_parent_process_alive && result);
    }
}

- (NSDictionary *)getMusicInfoForFile:(oneway NSString *)file
{
    NSError *error = nil;
    QTMovie *movie = [[[QTMovie alloc] initWithFile:file error:&error] autorelease];
    
    if ( movie != nil && error == nil )
    {
        NSMutableDictionary *arguments = [NSMutableDictionary dictionary];
        
        [arguments setValue:[NSArray arrayWithObject:@"Sound"] forKey:@"kMDItemMediaTypes"];
        
        [arguments setValue:[NSNumber numberWithFloat:[movie durationInSeconds]] forKey:@"kMDItemDurationSeconds"];
        
        // Get the meta data from the QTMovie
        NSString *name = [movie attributeWithFourCharCode:kUserDataTextFullName];
        if (!name || [name length] == 0)
        {
            name = [[file lastPathComponent] stringByDeletingPathExtension];
        }
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
        
        return arguments;
    }
    
    return nil;
}

@end

int main (int argc, const char * argv[])
{
    EnterMovies();
    
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    
    NSApplicationLoad();
    
    NSString *serverIdentifier = [NSString stringWithCString:argv[1]];
    
    int parentProcessIdentifier = atoi(argv[2]);
    
    if ( parentProcessIdentifier > 0 )
    {
        MainThread *server = [[[MainThread alloc] initWithServerIdentifier:serverIdentifier parentProcessIdentifier:parentProcessIdentifier] autorelease];
        
        [server run];
    }
    
    [pool release];
    
    ExitMovies();
    
    return 0;
}
