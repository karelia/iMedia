/*
 iMedia Browser Framework <http://karelia.com/imedia/>
 
 Copyright (c) 2005-2010 by Karelia Software et al.
 
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
	following copyright notice: Copyright (c) 2005-2010 by Karelia Software et al.
 
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


// LocalizedStringInIMedia is for use by frameworks and plugins,
// so it gets the right bundle -- not the application bundle.
// Code in the application itself should always use NSLocalizedString

#import <iMediaBrowser/LibraryItemsValueTransformer.h>
#import <iMediaBrowser/MUPhotoView.h>
#import <iMediaBrowser/NSAttributedString+iMedia.h>
#import <iMediaBrowser/NSFileManager+iMedia.h>
#import <iMediaBrowser/NSImage+iMedia.h>
#import <iMediaBrowser/NSIndexPath+iMedia.h>
#import <iMediaBrowser/NSPasteboard+iMedia.h>
#import <iMediaBrowser/NSPopUpButton+iMedia.h>
#import <iMediaBrowser/NSProcessInfo+iMedia.h>
#import <iMediaBrowser/NSSlider+iMedia.h>
#import <iMediaBrowser/NSString+iMedia.h>
#import <iMediaBrowser/NSWorkspace+iMedia.h>
#import <iMediaBrowser/QTMovie+iMedia.h>
#import <iMediaBrowser/RBSplitSubview.h>
#import <iMediaBrowser/RBSplitView.h>
#import <iMediaBrowser/TimeValueTransformer.h>
#import <iMediaBrowser/iMBAbstractParser.h>
#import <iMediaBrowser/iMBLibraryNode.h>
#import <iMediaBrowser/iMediaConfiguration.h>
#import <iMediaBrowser/iMediaBrowser.h>
