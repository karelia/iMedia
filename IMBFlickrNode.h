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

//	iMedia
#import <iMedia/IMBNode.h>



@class IMBParser;

extern NSString* const IMBFlickrNodeProperty_License;
extern NSString* const IMBFlickrNodeProperty_Method;
extern NSString* const IMBFlickrNodeProperty_Query;
extern NSString* const IMBFlickrNodeProperty_SortOrder;
extern NSString* const IMBFlickrNodeProperty_UUID;

typedef enum {
	IMBFlickrNodeMethod_TextSearch = 0,
	IMBFlickrNodeMethod_TagSearch,
	IMBFlickrNodeMethod_Recent,
	IMBFlickrNodeMethod_MostInteresting,
	IMBFlickrNodeMethod_GetInfo
} IMBFlickrNodeMethod;

typedef enum {
	IMBFlickrNodeLicense_Undefined = 0,
	IMBFlickrNodeLicense_CreativeCommons,
	IMBFlickrNodeLicense_DerivativeWorks,
	IMBFlickrNodeLicense_CommercialUse
} IMBFlickrNodeLicense;

///	License kinds and ids as found under http://www.flickr.com/services/api/flickr.photos.licenses.getInfo.html
typedef enum {
	IMBFlickrNodeFlickrLicenseID_Undefined = 0,
	IMBFlickrNodeFlickrLicenseID_AttributionNonCommercialShareAlike = 1,
	IMBFlickrNodeFlickrLicenseID_AttributionNonCommercial = 2,
	IMBFlickrNodeFlickrLicenseID_AttributionNonCommercialNoDerivs = 3,
	IMBFlickrNodeFlickrLicenseID_Attribution = 4,
	IMBFlickrNodeFlickrLicenseID_AttributionShareAlike = 5,
	IMBFlickrNodeFlickrLicenseID_AttributionNoDerivs = 6,
	IMBFlickrNodeFlickrLicenseID_NoKnownCopyrightRestrictions = 7
} IMBFlickrNodeFlickrLicenseID;

typedef enum {
	IMBFlickrNodeSortOrder_Undefined = 0,
	IMBFlickrNodeSortOrder_DatePostedDesc,
	IMBFlickrNodeSortOrder_DatePostedAsc,
	IMBFlickrNodeSortOrder_DateTakenDesc,
	IMBFlickrNodeSortOrder_DateTakenAsc,
	IMBFlickrNodeSortOrder_InterestingnessDesc,
	IMBFlickrNodeSortOrder_InterestingnessAsc,
	IMBFlickrNodeSortOrder_Relevance
} IMBFlickrNodeSortOrder;

/**
 *	Flickr parser custom node holding some additions to the iMB node construct queries to Flickr.
 *
 *	@author  Christoph Priebe (cp)
 *	@since   iMedia 2.0
 */
@interface IMBFlickrNode: IMBNode <NSCopying, NSCoding> {
	@private
	BOOL _customNode;
	IMBFlickrNodeLicense _license;
	IMBFlickrNodeMethod _method;
	NSInteger _page;
	NSString* _query;
	IMBFlickrNodeSortOrder _sortOrder;
}

#pragma mark Construction

+ (IMBFlickrNode*) flickrNodeForInterestingPhotosForRoot: (IMBFlickrNode*) root
												  parser: (IMBParser*) parser;

+ (IMBFlickrNode*) flickrNodeForRecentPhotosForRoot: (IMBFlickrNode*) root
											 parser: (IMBParser*) parser;

+ (IMBFlickrNode*) flickrNodeForRoot: (IMBFlickrNode*) root
							  parser: (IMBParser*) parser;

+ (IMBFlickrNode*) flickrNodeFromDictionary: (NSDictionary*) dictionary 
								   rootNode: (IMBFlickrNode*) root
									 parser: (IMBParser*) parser;

+ (void) sendSelectNodeNotificationForDict: (NSDictionary*) dict;


#pragma mark Properties

@property (assign, getter=isCustomNode) BOOL customNode;
@property (assign) IMBFlickrNodeLicense license;
@property (assign) IMBFlickrNodeMethod method;
@property (assign) NSInteger page;
@property (copy) NSString* query;
@property (assign) IMBFlickrNodeSortOrder sortOrder;


#pragma mark Utilities

+ (NSString*) base58EncodedValue: (long long) num;
+ (NSString*) descriptionOfLicense: (int) aLicenseNumber;
+ (NSString*) identifierWithQueryParams: (NSDictionary*) inQueryParams;
- (void) readPropertiesFromDictionary: (NSDictionary*) dictionary;

@end
