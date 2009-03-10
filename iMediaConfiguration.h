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

#import <Cocoa/Cocoa.h>

@class iMBLibraryNode;
@class iMBParserController;
@class iMBAbstractParser;

@interface iMediaConfiguration : NSObject {
    IBOutlet id configurationDelegate;

@private
    NSMutableDictionary *myParserControllers;
    NSMutableDictionary *myCustomFolderParsers;
	NSArray *excludedFolders;
    
    NSString *myIdentifier;
    
    BOOL showFilenames;
}

+ (id)sharedConfiguration;
+ (id)sharedConfigurationWithDelegate:(id)delegate;

+ (void)registerParser:(Class)aClass forMediaType:(NSString *)media;
+ (void)unregisterParserName:(NSString *)parserClassName forMediaType:(NSString *)media;
+ (void)unregisterParser:(Class)parserClass forMediaType:(NSString *)media;

+ (void)setLiveUpdatingEnabled:(BOOL)enabled;
+ (BOOL)isLiveUpdatingEnabled;

#pragma mark -
#pragma mark Custom folder handling

// TODO: Make aClass a id<protocol> that must respond to initWithContentsOfFile: ?
- (void)registerCustomFolderParser:(Class)aClass forMediaType:(NSString *)mediaType;
- (void)unregisterCustomFolderParserForMediaType:(NSString *)mediaType;
- (BOOL)hasCustomFolderParserForMediaType:(NSString *)mediaType;
- (iMBAbstractParser *)createCustomFolderParserForMediaType:(NSString *)mediaType folderPath:(NSString *)folderPath;

- (NSDictionary *)parsers;

- (NSArray *)excludedFolders;
- (void)setExcludedFolders:(NSArray *)someFolders;

- (void)setIdentifier:(NSString *)identifier;
- (NSString *)identifier;

- (void)setShowsFilenamesInPhotoBasedBrowsers:(BOOL)flag;	// API to set initial value
- (BOOL)prefersFilenamesInPhotoBasedBrowsers;				// binding for user defaults
- (void)setPrefersFilenamesInPhotoBasedBrowsers:(BOOL)flag;	// binding for user defaults

- (iMBParserController *)parserControllerForMediaType:(NSString *)mediaType;


#pragma mark -
#pragma mark Delegate

- (void)setDelegate:(id)delegate;
- (id)delegate;

@end

@interface NSObject (iMediaConfigurationDelegate)

// NB: These methods will be called on the main thread
// the delegate can stop the browser from loading a certain media type
- (BOOL)iMediaConfiguration:(iMediaConfiguration *)configuration willLoadBrowser:(NSString *)browserClassname;
- (void)iMediaConfiguration:(iMediaConfiguration *)configuration didLoadBrowser:(NSString *)browserClassname;

// Contextual menu support
- (NSMenu*)iMediaConfiguration:(iMediaConfiguration *)configuration menuForSelectedObjects:(NSArray*)selection;

// NB: These delegate methods will most likely not be called on the main thread so you will have to make sure you code can handle this.
// loading different parsers for media types
- (BOOL)iMediaConfiguration:(iMediaConfiguration *)configuration willUseMediaParser:(NSString *)parserClassname forMediaType:(NSString *)media;
- (void)iMediaConfiguration:(iMediaConfiguration *)configuration didUseMediaParser:(NSString *)parserClassname forMediaType:(NSString *)media;

- (void)iMediaConfiguration:(iMediaConfiguration *)configuration didSelectNode:(iMBLibraryNode *)node;
- (void)iMediaConfiguration:(iMediaConfiguration *)configuration willExpandOutline:(NSOutlineView *)outline row:(id)row node:(iMBLibraryNode *)node;

- (BOOL)horizontalSplitViewForMediaConfiguration:(iMediaConfiguration *)configuration;

@end
