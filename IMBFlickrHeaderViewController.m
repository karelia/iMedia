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


// Author: Peter Baumgartner


//----------------------------------------------------------------------------------------------------------------------


#pragma mark HEADERS

#import "IMBFlickrHeaderViewController.h"
#import "IMBFlickrParser.h"
#import "IMBFlickrNode.h"
#import "IMBCommon.h"
#import "NSString+iMedia.h"


//----------------------------------------------------------------------------------------------------------------------


#pragma mark

@implementation IMBFlickrHeaderViewController

@synthesize parser = _parser;
@synthesize owningNode = _owningNode;
@synthesize queryParams = _queryParams;
@synthesize queryAction = _queryAction;
@synthesize buttonAction = _buttonAction;
@synthesize buttonTitle = _buttonTitle;


//----------------------------------------------------------------------------------------------------------------------


+ (IMBFlickrHeaderViewController*) headerViewControllerWithParser:(IMBFlickrParser*)inParser owningNode:(IMBFlickrNode*)inNode
{
	IMBFlickrHeaderViewController* controller = [[[IMBFlickrHeaderViewController alloc] init] autorelease];
	controller.parser = inParser;
	controller.owningNode = inNode;
	return controller;
}


//----------------------------------------------------------------------------------------------------------------------


- (id) init 
{
    if (self = [super initWithNibName:@"IMBFlickrHeaderView" bundle:IMBBundle()])
	{
		self.queryParams = [NSMutableDictionary dictionary];
		self.queryAction = @selector(editQuery:);
    }
	
    return self;
}


- (void) awakeFromNib
{
	// Configure the search field...
	
	[_queryField setAction:_queryAction];
	[_queryField setTarget:self];
	
	// Configure the popup menu...

	NSMenuItem* item = nil;
	NSString* title = nil;
	NSMenu* menu  = [[[NSMenu alloc] initWithTitle:@""] autorelease];
	
	title = NSLocalizedStringWithDefaultValue(@"IMBFlickrParser.menu.searchIn",nil,IMBBundle(),@"Search in",@"Menu item in Flickr options popup");
	item = [[NSMenuItem alloc] initWithTitle:title action:@selector(disabledAction:) keyEquivalent:@""];
	item.target = self;
	item.tag = 0;
	[menu addItem:item];
	[item release];
	
	title = NSLocalizedStringWithDefaultValue(@"IMBFlickrParser.menu.text",nil,IMBBundle(),@"Text",@"Menu item in Flickr options popup");
	item = [[NSMenuItem alloc] initWithTitle:title action:@selector(setSearchType:) keyEquivalent:@""];
	item.target = self;
	item.tag = 0;
	[menu addItem:item];
	[item release];

	title = NSLocalizedStringWithDefaultValue(@"IMBFlickrParser.menu.tag",nil,IMBBundle(),@"Tag",@"Menu item in Flickr options popup");
	item = [[NSMenuItem alloc] initWithTitle:title action:@selector(setSearchType:) keyEquivalent:@""];
	item.target = self;
	item.tag = 1;
	[menu addItem:item];
	[item release];

	[menu addItem:[NSMenuItem separatorItem]];
	
	title = NSLocalizedStringWithDefaultValue(@"IMBFlickrParser.menu.license",nil,IMBBundle(),@"License",@"Menu item in Flickr options popup");
	item = [[NSMenuItem alloc] initWithTitle:title action:@selector(disabledAction:) keyEquivalent:@""];
	item.target = self;
	item.tag = 0;
	[menu addItem:item];
	[item release];

	title = NSLocalizedStringWithDefaultValue(@"IMBFlickrParser.menu.any",nil,IMBBundle(),@"Any",@"Menu item in Flickr options popup");
	item = [[NSMenuItem alloc] initWithTitle:title action:@selector(setLicense:) keyEquivalent:@""];
	item.target = self;
	item.tag = 0;
	[menu addItem:item];
	[item release];

	title = NSLocalizedStringWithDefaultValue(@"IMBFlickrParser.menu.creativeCommons",nil,IMBBundle(),@"Creative Commons",@"Menu item in Flickr options popup");
	item = [[NSMenuItem alloc] initWithTitle:title action:@selector(setLicense:) keyEquivalent:@""];
	item.target = self;
	item.tag = 1;
	[menu addItem:item];
	[item release];

	title = NSLocalizedStringWithDefaultValue(@"IMBFlickrParser.menu.derivativeWorks",nil,IMBBundle(),@"Derivative Works",@"Menu item in Flickr options popup");
	item = [[NSMenuItem alloc] initWithTitle:title action:@selector(setLicense:) keyEquivalent:@""];
	item.target = self;
	item.tag = 2;
	[menu addItem:item];
	[item release];

	title = NSLocalizedStringWithDefaultValue(@"IMBFlickrParser.menu.commercialUse",nil,IMBBundle(),@"Commercial Use",@"Menu item in Flickr options popup");
	item = [[NSMenuItem alloc] initWithTitle:title action:@selector(setLicense:) keyEquivalent:@""];
	item.target = self;
	item.tag = 3;
	[menu addItem:item];
	[item release];

	[menu addItem:[NSMenuItem separatorItem]];
	
	title = NSLocalizedStringWithDefaultValue(@"IMBFlickrParser.menu.chooseBy",nil,IMBBundle(),@"Choose by",@"Menu item in Flickr options popup");
	item = [[NSMenuItem alloc] initWithTitle:title action:@selector(disabledAction:) keyEquivalent:@""];
	item.target = self;
	item.tag = 0;
	[menu addItem:item];
	[item release];

	title = NSLocalizedStringWithDefaultValue(@"IMBFlickrParser.menu.relevance",nil,IMBBundle(),@"Relevance",@"Menu item in Flickr options popup");
	item = [[NSMenuItem alloc] initWithTitle:title action:@selector(setSortOrder:) keyEquivalent:@""];
	item.target = self;
	item.tag = 7;
	[menu addItem:item];
	[item release];

	title = NSLocalizedStringWithDefaultValue(@"IMBFlickrParser.menu.interest",nil,IMBBundle(),@"Interest",@"Menu item in Flickr options popup");
	item = [[NSMenuItem alloc] initWithTitle:title action:@selector(setSortOrder:) keyEquivalent:@""];
	item.target = self;
	item.tag = 5;
	[menu addItem:item];
	[item release];

	title = NSLocalizedStringWithDefaultValue(@"IMBFlickrParser.menu.dateTaken",nil,IMBBundle(),@"Date Taken",@"Menu item in Flickr options popup");
	item = [[NSMenuItem alloc] initWithTitle:title action:@selector(setSortOrder:) keyEquivalent:@""];
	item.target = self;
	item.tag = 3;
	[menu addItem:item];
	[item release];

	title = NSLocalizedStringWithDefaultValue(@"IMBFlickrParser.menu.datePosted",nil,IMBBundle(),@"Date Posted",@"Menu item in Flickr options popup");
	item = [[NSMenuItem alloc] initWithTitle:title action:@selector(setSortOrder:) keyEquivalent:@""];
	item.target = self;
	item.tag = 1;
	[menu addItem:item];
	[item release];

	NSSearchFieldCell* cell = (NSSearchFieldCell*) [_queryField cell];
	[cell setSearchMenuTemplate:menu];
	
	// Configure the button...
	
	[_button setTitle:_buttonTitle];
	[_button setAction:_buttonAction];
	[_button setTarget:self];
}


- (void) dealloc
{
	[NSObject cancelPreviousPerformRequestsWithTarget:self];
	IMBRelease(_queryParams);
	IMBRelease(_buttonTitle);
	[super dealloc];
}


//----------------------------------------------------------------------------------------------------------------------


- (void) _updateNodes
{
	[_parser saveCustomQueries];
	[_parser reloadCustomQueries];
}


- (IBAction) addQuery:(id)inSender
{
	NSMutableDictionary* queryParams = [NSMutableDictionary dictionary];
	[queryParams setObject:[_queryField stringValue] forKey:IMBFlickrNodeProperty_Query];	
	[queryParams setObject:[NSNumber numberWithInt:IMBFlickrNodeMethod_TextSearch] forKey:IMBFlickrNodeProperty_Method];
	[queryParams setObject:[NSNumber numberWithInt:IMBFlickrNodeLicense_CreativeCommons] forKey:IMBFlickrNodeProperty_License];
	[queryParams setObject:[NSNumber numberWithInt:IMBFlickrNodeSortOrder_InterestingnessDesc] forKey:IMBFlickrNodeProperty_SortOrder];
	[queryParams setObject:[NSString uuid] forKey:IMBFlickrNodeProperty_UUID];

	[_parser addCustomQuery:queryParams];
	[self _updateNodes];
	
	[IMBFlickrNode sendSelectNodeNotificationForDict:queryParams];
}


- (IBAction) editQuery:(id)inSender
{
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(_updateNodes) object:nil];
	[self performSelector:@selector(_updateNodes) withObject:nil afterDelay:0.5 inModes:[NSArray arrayWithObject:(NSString*)kCFRunLoopCommonModes]];
}


- (IBAction) removeQuery:(id)inSender
{
	if (self.queryParams)
	{
		[_parser removeCustomQuery:self.queryParams];
		[self _updateNodes];
	}
}


//----------------------------------------------------------------------------------------------------------------------


- (IBAction) setSearchType:(id)inSender
{
	NSInteger tag = [inSender tag];
	[_queryParams setObject:[NSNumber numberWithInteger:tag] forKey:IMBFlickrNodeProperty_Method];
	[self _updateNodes];
}


- (IBAction) setLicense:(id)inSender
{
	NSInteger tag = [inSender tag];
	[_queryParams setObject:[NSNumber numberWithInteger:tag] forKey:IMBFlickrNodeProperty_License];
	[self _updateNodes];
}


- (IBAction) setSortOrder:(id)inSender
{
	NSInteger tag = [inSender tag];
	[_queryParams setObject:[NSNumber numberWithInteger:tag] forKey:IMBFlickrNodeProperty_SortOrder];
	[self _updateNodes];
}


- (IBAction) disabledAction:(id)inSender
{
	// Dummy action to make validateMenuItem: work as intended...
}


- (BOOL) validateMenuItem:(NSMenuItem*)inMenuItem
{
	SEL action = [inMenuItem action];
	NSInteger tag = [inMenuItem tag];
	NSInteger method = [[_queryParams objectForKey:IMBFlickrNodeProperty_Method] integerValue];
	NSInteger license = [[_queryParams objectForKey:IMBFlickrNodeProperty_License] integerValue];
	NSInteger sortOrder = [[_queryParams objectForKey:IMBFlickrNodeProperty_SortOrder] integerValue];
	
	if (action == @selector(setSearchType:))
	{
		[inMenuItem setState:tag == method];
		return YES;
	}
	else if (action == @selector(setLicense:))
	{
		[inMenuItem setState:tag == license];
		return YES;
	}
	else if (action == @selector(setSortOrder:))
	{
		[inMenuItem setState:tag == sortOrder];
		return YES;
	}
	
	[inMenuItem setState:NO];
	return NO;
}


//----------------------------------------------------------------------------------------------------------------------


@end
