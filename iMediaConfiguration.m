/*
 iMedia Browser Framework <http://karelia.com/imedia/>
 
 Copyright (c) 2005-2009 by Karelia Software et al.
 
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
	following copyright notice: Copyright (c) 2005-2009 by Karelia Software et al.
 
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

#import "iMediaConfiguration.h"
#import "iMBParserController.h"
#import "LibraryItemsValueTransformer.h"
#import "MUPhotoView.h"

static iMediaConfiguration *_sharedMediaConfiguration = nil;

static NSMutableDictionary *_parsers = nil;

static BOOL _liveUpdatingEnabled = NO;

@implementation iMediaConfiguration

+ (void)initialize	// preferred over +load in most cases
{
	if ( self == [iMediaConfiguration class] ) 
	{
		// Only do some work when not called because one of our subclasses does not implement +initialize

        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

        _parsers = [[NSMutableDictionary dictionary] retain];
        
        // TODO: commented out (currently only supported in iMediaBrowser)
/*		
        //find and load all plugins
        NSArray *plugins = [iMediaBrowser findBundlesWithExtension:@"iMediaBrowser" inFolderName:@"iMediaBrowser"];
        NSEnumerator *e = [plugins objectEnumerator];
        NSString *cur;
        
        while (cur = [e nextObject])
        {
            NSBundle *b = [NSBundle bundleWithPath:cur];
            Class mainClass = [b principalClass];
            if ([mainClass conformsToProtocol:@protocol(iMediaBrowser)] || [mainClass conformsToProtocol:@protocol(iMBParser)]) 
            {
                if (![b load])
                {
                    NSLog(@"Failed to load iMediaBrowser plugin: %@", cur);
                    continue;
                }
                else
                {
                    // Register the parser/browser.  Note that the main class might be both!
                    // (Alternatively -- have a wakeup method sent to the main class to let it do its
                    // own registration, in case they are separate classes.)
                    
    //				if ([mainClass conformsToProtocol:@protocol(iMediaBrowser)])
    //				{
    //					[self registerBrowser:mainClass];
    //				}
    //				if ([mainClass conformsToProtocol:@protocol(iMBParser)])
    //				{
    //					[self registerParser:mainClass];
    //				}
                }
            }
            else
            {
                NSLog(@"Plugin located at: %@ does not implement either of the required protocols", cur);
            }
        }
*/
        [pool release];
    }
}

+ (id)sharedConfiguration
{
    @synchronized(self)
    {
        if (!_sharedMediaConfiguration)
            _sharedMediaConfiguration = [[iMediaConfiguration alloc] init];
    }
    
    return _sharedMediaConfiguration;
}

+ (id)sharedConfigurationWithDelegate:(id)delegate
{
	iMediaConfiguration *configuration = [self sharedConfiguration];

	[configuration setDelegate:delegate];
    
	return configuration;
}

+ (void)registerParser:(Class)aClass forMediaType:(NSString *)media
{
	NSAssert(aClass != NULL, @"aClass is NULL");
	NSAssert(media != nil, @"media is nil");
	
	NSMutableArray *parsers = [_parsers objectForKey:media];
    
	if (!parsers)
	{
		parsers = [NSMutableArray array];
		[_parsers setObject:parsers forKey:media];
	}
    
    if (aClass != Nil)
        [parsers addObject:NSStringFromClass(aClass)];
}

+ (void)unregisterParserName:(NSString *)parserClassName forMediaType:(NSString *)media
{
	NSEnumerator *e = [[_parsers objectForKey:media] objectEnumerator];
	NSString *cur;
    
	while (cur = [e nextObject])
    {
		if ([parserClassName isEqualToString:cur])
        {
			[[_parsers objectForKey:media] removeObject:cur];
		
            return;
		}
	}
}

+ (void)unregisterParser:(Class)parserClass forMediaType:(NSString *)media
{
	[iMediaConfiguration unregisterParserName:NSStringFromClass(parserClass) forMediaType:media];
}

+ (void)setLiveUpdatingEnabled:(BOOL)enabled
{
	_liveUpdatingEnabled = enabled;
}

+ (BOOL)isLiveUpdatingEnabled
{
	return _liveUpdatingEnabled;
}

- (id)init
{
	if (self = [super init])
    {
		[self setIdentifier:@"Default"];
        
        myParserControllers = [[NSMutableDictionary alloc] init];
        myCustomFolderParsers = [[NSMutableDictionary alloc] init];
	}
    
	return self;
}

- (void)dealloc
{
    [myIdentifier release]; myIdentifier = NULL;
    [excludedFolders release]; excludedFolders = NULL;
    [myParserControllers release]; myParserControllers = NULL;
    [myCustomFolderParsers release]; myCustomFolderParsers = NULL;
    [super dealloc];
}

- (NSDictionary *)parsers
{
    return _parsers;
}

- (NSArray *)excludedFolders
{
    return [[excludedFolders retain] autorelease];
}

- (void)setExcludedFolders:(NSArray *)someFolders
{
    if (excludedFolders != someFolders)
    {
        [excludedFolders release];

        excludedFolders = [someFolders copy];
    }
}

- (void)setIdentifier:(NSString *)identifier
{
	if (identifier != myIdentifier)
	{
		[myIdentifier autorelease];
		myIdentifier = [identifier copy];
	}
}

- (NSString *)identifier
{
	return [[myIdentifier retain] autorelease];
}


// This is a method that a client can call to set the default value of whether
// captions are shown.  Users can override this by checking checkbox on "back" of window.

- (void)setShowsFilenamesInPhotoBasedBrowsers:(BOOL)flag
{
	showFilenames = flag;
}

// variation of the above that also sets a preference - for binding

- (void)setPrefersFilenamesInPhotoBasedBrowsers:(BOOL)flag
{
	[self setShowsFilenamesInPhotoBasedBrowsers:flag];	// set internal value

	NSDictionary *info = [NSDictionary dictionaryWithObjectsAndKeys:
		[NSNumber numberWithBool:flag], @"flag", 
		nil];
	[[NSNotificationCenter defaultCenter]
			postNotificationName:ShowCaptionChangedNotification
						  object:self
						userInfo:info];
	
	[[NSUserDefaults standardUserDefaults] setBool:flag forKey:[NSString stringWithFormat:@"iMBShowCaptions-%@", myIdentifier]];
}

- (BOOL)prefersFilenamesInPhotoBasedBrowsers
{
	id preferred = [[NSUserDefaults standardUserDefaults] objectForKey:[NSString stringWithFormat:@"iMBShowCaptions-%@", myIdentifier]];
	if (nil != preferred)
	{
		return [preferred boolValue];
	}
	return showFilenames;	// return the fallback set through code
}

- (iMBParserController *)parserControllerForMediaType:(NSString *)mediaType
{
    iMBParserController *parserController = NULL;
    
    @synchronized (self)
    {
        parserController = [myParserControllers objectForKey:mediaType];
        
        if (parserController == NULL)
        {
            parserController = [[[iMBParserController alloc] initWithMediaType:mediaType] autorelease];
            [myParserControllers setObject:parserController forKey:mediaType];
        }
    }
    
    return parserController;
}

#pragma mark -
#pragma mark Custom folder handling

- (void)registerCustomFolderParser:(Class)aClass forMediaType:(NSString *)mediaType
{
    @synchronized (myCustomFolderParsers)
    {
        [myCustomFolderParsers setObject:aClass forKey:mediaType];
    }
}

- (void)unregisterCustomFolderParserForMediaType:(NSString *)mediaType
{
    @synchronized (myCustomFolderParsers)
    {
        [myCustomFolderParsers removeObjectForKey:mediaType];
    }
}

- (BOOL)hasCustomFolderParserForMediaType:(NSString *)mediaType
{
    BOOL result = NO;
    @synchronized (myCustomFolderParsers)
    {
        result = [myCustomFolderParsers objectForKey:mediaType] != NULL;
    }
    return result;
}

- (iMBAbstractParser *)createCustomFolderParserForMediaType:(NSString *)mediaType folderPath:(NSString *)folderPath
{
    iMBAbstractParser *parser = NULL;
    @synchronized (myCustomFolderParsers)
    {
        Class parserClass = [myCustomFolderParsers objectForKey:mediaType];
        if (parserClass != NULL)
        {
            parser = [[[parserClass alloc] initWithContentsOfFile:folderPath] autorelease];
        }
    }
    return parser;
}

#pragma mark -
#pragma mark Delegate

- (void)setDelegate:(id)delegate
{
	configurationDelegate = delegate;	// not retained
}

- (id)delegate
{
	return configurationDelegate;
}

@end
