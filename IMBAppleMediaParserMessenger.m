/*
 iMedia Browser Framework <http://karelia.com/imedia/>
 
 Copyright (c) 2005-2012 by Karelia Software et al.
 
 iMedia Browser is based on code originally developed by Jason Terhorst,
 further developed for Sandvox by Greg Hulands, Dan Wood, and Terrence Talbot.
 The new architecture for version 2.0 was developed by Peter Baumgartner.
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
 following copyright notice: Copyright (c) 2005-2012 by Karelia Software et al.
 
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


// Author: Jörg Jacobsen


//----------------------------------------------------------------------------------------------------------------------

#import "SBUtilities.h"
#import "NSWorkspace+iMedia.h"
#import "NSFileManager+iMedia.h"
#import "IMBConfig.h"
#import "IMBAppleMediaParserMessenger.h"
#import "IMBAppleMediaParser.h"
#import "IMBNode.h"
#import "IMBiPhotoEventObjectViewController.h"
#import "IMBFaceObjectViewController.h"


@implementation IMBAppleMediaParserMessenger


// Returns the list of parsers this messenger instantiated. Array should be static. Must be subclassed.

+ (NSMutableArray *)parsers
{
    NSString *errMsg = [NSString stringWithFormat:@"%@: Please use a custom subclass of %@...", _cmd, [self className]];
	NSLog(@"%@", errMsg);
	[[NSException exceptionWithName:@"IMBProgrammerError" reason:errMsg userInfo:nil] raise];
	
	return nil;
}

// Returns the dispatch-once token. Token must be static. Must be subclassed.

+ (dispatch_once_t *)onceTokenRef
{
    NSString *errMsg = [NSString stringWithFormat:@"%@: Please use a custom subclass of %@...", _cmd, [self className]];
	NSLog(@"%@", errMsg);
	[[NSException exceptionWithName:@"IMBProgrammerError" reason:errMsg userInfo:nil] raise];
	
	return 0;
}

//----------------------------------------------------------------------------------------------------------------------

// Returns the bundle identifier of the associated app. Must be subclassed.

+ (NSString *) bundleIdentifier
{
    NSString *errMsg = [NSString stringWithFormat:@"%@: Please use a custom subclass of %@...", _cmd, [self className]];
	NSLog(@"%@", errMsg);
	[[NSException exceptionWithName:@"IMBProgrammerError" reason:errMsg userInfo:nil] raise];
	
	return nil;
}


// Check if App is installed (iPhoto or Aperture)

+ (NSString*) appPath
{
	return [[NSWorkspace imb_threadSafeWorkspace] absolutePathForAppBundleWithIdentifier:[self bundleIdentifier]];
}


+ (BOOL) isInstalled
{
	return [self appPath] != nil;
}


+ (BOOL) isEventsNode:(IMBNode *)inNode
{
    return [[inNode.attributes objectForKey:@"nodeType"] isEqual:kIMBiPhotoNodeObjectTypeEvent];
}


+ (BOOL) isFacesNode:(IMBNode *)inNode
{
    return [[inNode.attributes objectForKey:@"nodeType"] isEqual:kIMBiPhotoNodeObjectTypeFace];
}


- (id) init
{
	if ((self = [super init]))
	{
		self.mediaSource = nil;	// Will be discovered in XPC service
		self.mediaType = [[self class] mediaType];
		self.isUserAdded = NO;
	}
	
	return self;
}


//----------------------------------------------------------------------------------------------------------------------


// This method is called on the XPC service side. Discover the path to the AlbumData.xml file and create  
// an IMBParser instance preconfigured with that path...

- (NSArray*) parserInstancesWithError:(NSError**)outError
{
    NSMutableArray *parsers = [[self class] parsers];
    dispatch_once([[self class] onceTokenRef],
                  ^{
                      if ([[self class] isInstalled])
                      {
                          CFArrayRef recentLibraries = SBPreferencesCopyAppValue((CFStringRef)@"iPhotoRecentDatabases",(CFStringRef)@"com.apple.iApps");
                          NSArray* libraries = (NSArray*)recentLibraries;
                          
                          for (NSString* library in libraries)
                          {
                              NSURL* url = [NSURL URLWithString:library];
                              NSString* path = [url path];
                              BOOL changed;
                              
                              if ([[NSFileManager imb_threadSafeManager] imb_fileExistsAtPath:&path wasChanged:&changed])
                              {
                                  // Create a parser instance preconfigure with that path...
                                  
                                  IMBAppleMediaParser* parser = (IMBAppleMediaParser*)[self newParser];
                                  
                                  parser.identifier = [NSString stringWithFormat:@"%@:/%@",[[self class] identifier],path];
                                  parser.mediaType = self.mediaType;
                                  parser.mediaSource = [NSURL fileURLWithPath:path];
                                  parser.appPath = [[self class ] appPath];
                                  
                                  [parsers addObject:parser];
                                  [parser release];
                                  
                                  // Exclude enclosing folder from being displayed by IMBFolderParser...
                                  
                                  NSString* libraryPath = [path stringByDeletingLastPathComponent];
                                  [IMBConfig registerLibraryPath:libraryPath];
                              }
                          }
                      }
                  });
	
	return (NSArray*)parsers;
}


//----------------------------------------------------------------------------------------------------------------------


#pragma mark -
#pragma mark Custom view controller support

- (NSViewController*) customObjectViewControllerForNode:(IMBNode*)inNode
{
    // Use custom view for events
    
    if ([[self class] isEventsNode:inNode])
    {
        NSViewController* viewController = [[[IMBiPhotoEventObjectViewController alloc] init] autorelease];
        [viewController view];
        return viewController;
    }
    
    if ([[self class] isFacesNode:inNode])
    {
        NSViewController* viewController = [[[IMBFaceObjectViewController alloc] init] autorelease];
        [viewController view];
        return viewController;
    }
    
    return [super customObjectViewControllerForNode:inNode];
}

@end
