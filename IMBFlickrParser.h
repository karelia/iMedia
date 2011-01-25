/*
 iMedia Browser Framework <http://karelia.com/imedia/>
 
 Copyright (c) 2005-2011 by Karelia Software et al.
 
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
	following copyright notice: Copyright (c) 2005-2011 by Karelia Software et al.
 
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


// Author: Christoph Priebe


//----------------------------------------------------------------------------------------------------------------------


//	System
#import <Cocoa/Cocoa.h>

//	iMedia
#import "IMBNode.h"
#import "IMBParser.h"

//----------------------------------------------------------------------------------------------------------------------

@class IMBFlickrQueryEditor;
@class IMBLoadMoreObject;
@class OFFlickrAPIContext;
/**
 *	iMedia parser to read public Flickr images.
 *	
 *	You need to supply your own Flickr API key and shared secret to use this 
 *	parser. Apply for key and secret at: http://flickr.com/services/api/keys/apply
 *
 *	Set the API key and shared secret in the IMBParserController delegate method
 *	parserController:didLoadParser:forMediaType: See the iMedia Test Application for 
 *	an example.
 *
 *
 *	@date 2009-08-24 Start implementing this class (cp).
 *
 *	@author  Christoph Priebe (cp)
 *	@since   iMedia 2.0
 */
 
@interface IMBFlickrParser: IMBParser {
	@private
	IMBFlickrSizeSpecifier _desiredSize;
	NSMutableArray* _customQueries;
	id _delegate;
	IMBFlickrQueryEditor* _editor;
	NSString* _flickrAPIKey;
	OFFlickrAPIContext* _flickrContext;
	NSString* _flickrSharedSecret;
	IMBLoadMoreObject* _loadMoreButton;
}

#pragma mark Actions

- (IBAction) loadMoreImages: (id) sender;

- (IBAction) openFlickrPage: (id) sender;

- (IBAction) removeNode: (id) sender;


#pragma mark Properties

@property (assign) IMBFlickrSizeSpecifier desiredSize;

@property (retain) NSMutableArray* customQueries;

@property (assign) id delegate;

///	The API key given to you by Flickr. Must be set to use this parser.
@property (copy) NSString* flickrAPIKey;

///	The shared secret given to you by Flickr. Must be set to use this parser.
@property (copy) NSString* flickrSharedSecret;

///	A button object holding the 'load more' button.
@property (readonly) IMBLoadMoreObject* loadMoreButton;


#pragma mark Query Persistence

- (void) addCustomQuery:(NSDictionary*)inQueryParams;
- (void) removeCustomQuery:(NSDictionary*)inQueryParams;

- (void) loadCustomQueries;
- (void) saveCustomQueries;
- (void) reloadCustomQueries;

@end



//----------------------------------------------------------------------------------------------------------------------

#pragma mark 

@protocol IMBFlickrParserDelegate

@optional

- (NSArray*) flickrParserSetupDefaultQueries: (IMBFlickrParser*) IMBFlickrParser;

@end

//----------------------------------------------------------------------------------------------------------------------

