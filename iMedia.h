/*
 
 Permission is hereby granted, free of charge, to any person obtaining a 
 copy of this software and associated documentation files (the "Software"), 
 to deal in the Software without restriction, including without limitation 
 the rights to use, copy, modify, merge, publish, distribute, sublicense, 
 and/or sell copies of the Software, and to permit persons to whom the Software 
 is furnished to do so, subject to the following conditions:
 
 The above copyright notice and this permission notice shall be included in 
 all copies or substantial portions of the Software.
 
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR 
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS 
 FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR 
 COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN
 AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION 
 WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 
 iMedia Browser Home Page: <http://imedia.karelia.com/>
 
 Please send fixes to <imedia@lists.karelia.com>   
 */

// LocalizedStringInThisBundle is for use by frameworks and plugins,
// so it gets the right bundle -- not the application bundle.
// Code in the application itself should always use NSLocalizedString
// But WARNING -- it won't work in Category Methods, since the class will have the wrong bundle.
// For that, you'll have to create a separate macro that gets you the correct bundle, and match
// your genstrings to that key.

#define LocalizedStringInThisBundle(key, comment) \
    [[NSBundle bundleForClass:[self class]] localizedStringForKey:(key) value:@"" table:nil]

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
#import <iMediaBrowser/iMBAbstractController.h>
#import <iMediaBrowser/iMBAbstractParser.h>
#import <iMediaBrowser/iMBLibraryNode.h>
#import <iMediaBrowser/iMediaBrowser.h>

