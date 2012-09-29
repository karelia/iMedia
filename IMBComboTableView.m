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


// Author: Dan Wood


/*
     File: IMBComboTableView.m
 Based on Apple Sample Code "AnimatedTableView"

*/

#import "IMBComboTableView.h"
#import "IMBComboTableViewAppearance.h"
#import "IMBComboTextCell.h"


//----------------------------------------------------------------------------------------------------------------------


@implementation IMBComboTableView


//----------------------------------------------------------------------------------------------------------------------

- (BOOL)wantsThumbnails;
{
	return YES;
}


// If we are using custom background and highlight colors, we may have to adjust the text colors accordingly,
// to make sure that text is always clearly readable...

//- (NSCell*) preparedCellAtColumn:(NSInteger)inColumn row:(NSInteger)inRow
//{
//	NSCell* cell = [super preparedCellAtColumn:inColumn row:inRow];
//	IMBComboTextCell* comboCell = (IMBComboTextCell*)cell;
//	NSMutableDictionary* attributes;
//	NSMutableParagraphStyle* style;
//	
//	if ([cell isKindOfClass:[IMBComboTextCell class]])
//	{
//		if ([comboCell isHighlighted])
//		{
//			if (_customHighlightedTextColor != nil)
//			{
//				style = [[NSMutableParagraphStyle alloc] init];
//				[style setLineBreakMode:NSLineBreakByTruncatingTail];
//
//				attributes = [[NSMutableDictionary alloc] initWithObjectsAndKeys:
//					_customHighlightedTextColor,NSForegroundColorAttributeName,
//					[NSFont systemFontOfSize:13.0],NSFontAttributeName,
//					style,NSParagraphStyleAttributeName,
//					nil];
//				comboCell.titleTextAttributes = attributes;
//				[attributes release];
//				
//				attributes = [[NSMutableDictionary alloc] initWithObjectsAndKeys:
//					[_customHighlightedTextColor colorWithAlphaComponent:0.5],NSForegroundColorAttributeName,
//					[NSFont systemFontOfSize:11.0],NSFontAttributeName,
//					style,NSParagraphStyleAttributeName,
//					nil];
//				comboCell.subtitleTextAttributes = attributes;
//				[attributes release];
//					
//				[style release];	
//			}
//		}
//		else
//		{
//			if (_customTextColor != nil)
//			{
//				style = [[NSMutableParagraphStyle alloc] init];
//				[style setLineBreakMode:NSLineBreakByTruncatingTail];
//
//				attributes = [[NSMutableDictionary alloc] initWithObjectsAndKeys:
//					_customTextColor,NSForegroundColorAttributeName,
//					[NSFont systemFontOfSize:13.0],NSFontAttributeName,
//					style,NSParagraphStyleAttributeName,
//					nil];
//				comboCell.titleTextAttributes = attributes;
//				[attributes release];
//
//				attributes = [[NSMutableDictionary alloc] initWithObjectsAndKeys:
//					[_customTextColor colorWithAlphaComponent:0.5],NSForegroundColorAttributeName,
//					[NSFont systemFontOfSize:11.0],NSFontAttributeName,
//					style,NSParagraphStyleAttributeName,
//					nil];
//				comboCell.subtitleTextAttributes = attributes;
//				[attributes release];
//					
//				[style release];	
//			}
//		}
//	}
//	
//	return cell;
//}


//----------------------------------------------------------------------------------------------------------------------

#pragma mark
#pragma mark Appearance

- (IMBTableViewAppearance*) defaultAppearance
{
    IMBComboTableViewAppearance* appearance = [[[IMBComboTableViewAppearance alloc] init] autorelease];
    
    NSMutableParagraphStyle* paragraphStyle = [[[NSMutableParagraphStyle alloc] init] autorelease];
    [paragraphStyle setLineBreakMode:NSLineBreakByTruncatingTail];
    
    appearance.rowTextAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                    [NSFont systemFontOfSize:13.0],NSFontAttributeName,
                                    paragraphStyle,NSParagraphStyleAttributeName,
                                    nil];
    
    appearance.rowTextHighlightAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                             [NSFont systemFontOfSize:13.0],NSFontAttributeName,
                                             [NSColor selectedMenuItemTextColor], NSForegroundColorAttributeName,
                                             paragraphStyle,NSParagraphStyleAttributeName,
                                             nil];
    
    appearance.subRowTextAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                       [NSFont systemFontOfSize:11.0],NSFontAttributeName,
                                       [[NSColor textColor] colorWithAlphaComponent:0.4], NSForegroundColorAttributeName,
                                       paragraphStyle,NSParagraphStyleAttributeName,
                                    nil];
    
    appearance.subRowTextHighlightAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                                [NSFont systemFontOfSize:11.0],NSFontAttributeName,
                                                [[NSColor selectedMenuItemTextColor] colorWithAlphaComponent:0.4], NSForegroundColorAttributeName,
                                                paragraphStyle,NSParagraphStyleAttributeName,
                                             nil];
    
   return appearance;
}


@end
