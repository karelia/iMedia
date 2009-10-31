/*
 iMedia Browser Framework <http://karelia.com/imedia/>
 
 Copyright (c) 2005-2009 by Karelia Software et al.
 
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


//----------------------------------------------------------------------------------------------------------------------


#pragma mark ABSTRACT

// This singleton class loads all registered parsers and keeps instances around for the duration of the app lifetime.
// A parser is thus an extremely long-lived object, which can store state and talk to asynchronous APIs. This gives
// developers the chance to implmenent parsers for web based services, Spotlight, Image Capture etc. Just before the
// app quits the parsers are unloaded, at which time they can clean up...


//----------------------------------------------------------------------------------------------------------------------


#pragma mark CLASSES

@class IMBParser;


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 

@interface IMBParserController : NSObject
{
	NSMutableDictionary* _loadedParsers;
	id _delegate;
	BOOL _loadingCustomParsers;
}

// Create singleton instance of the controller. Don't forget to set the delegate early in the app lifetime...

+ (IMBParserController*) sharedParserController;
@property (assign) id delegate;

// Register parser classes. This should be called from the +load method of a parser class...

+ (void) registerParserClass:(Class)inParserClass forMediaType:(NSString*)inMediaType;
+ (void) unregisterParserClass:(Class)inParserClass;
+ (NSMutableSet*) registeredParserClassesForMediaType:(NSString*)inMediaType;

// Load all supported parsers. The delegate can restrict which parsers are loaded...

- (void) loadParsers; 
- (void) unloadParsers; 

// Add/remove custom parsers. This is usually used for folder based parsers that are dragged into the outline view.
// Please note that this method should be called after loadRegisteredParsers...

- (BOOL) addCustomParser:(IMBParser*)inParser forMediaType:(NSString*)inMediaType;
- (BOOL) removeCustomParser:(IMBParser*)inParser;

// Save info about the custom parsers to the preferences and restore custom parsers from the preferences...

- (void) saveCustomParsersToPreferences;
- (void) loadCustomParsersFromPreferences;

// Returns an array of loaded parsers. This combines the regular parsers (which were instantiated by loadParsers)
// with the custom parsers (which were instantiated by the user or by loadCustomParsersFromPreferences)...

- (NSMutableArray*) loadedParsersForMediaType:(NSString*)inMediaType; 
- (NSMutableArray*) loadedParsers;

// Debugging support...

- (void) logRegisteredParsers;
- (void) logLoadedParsers;

@end


//----------------------------------------------------------------------------------------------------------------------


#pragma mark 

@protocol IMBParserControllerDelegate

@optional

// Called once on main thread early in app lifetime, when all parsers are registered and loaded. 
// Return NO to suppress loading a particular parser...

- (BOOL) controller:(IMBParserController*)inController shouldLoadParser:(Class)inParserClass forMediaType:(NSString*)inMediaType;
- (void) controller:(IMBParserController*)inController willLoadParser:(Class)inParserClass forMediaType:(NSString*)inMediaType;
- (void) controller:(IMBParserController*)inController didLoadParser:(IMBParser*)inParser forMediaType:(NSString*)inMediaType;
- (void) controller:(IMBParserController*)inController willUnloadParser:(IMBParser*)inParser forMediaType:(NSString*)inMediaType;

@end


//----------------------------------------------------------------------------------------------------------------------


