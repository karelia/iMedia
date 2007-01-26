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

#import <Cocoa/Cocoa.h>
#import "iMediaBrowserProtocol.h"

@class iMBLibraryNode, UKKQueue;

@interface iMBAbstractParser : NSObject <iMBParser>
{
	NSString			*myDatabase;
	UKKQueue			*myFileWatcher;
	iMBLibraryNode		*myCachedLibrary;
	id <iMediaBrowser>	myBrowser;
}

// default initializer from the protocol
- (id)init;

// We provide by default the ability to watch for external changes to the databases. 
// subclasses call this super method if they want auto watching of the db file.
- (id)initWithContentsOfFile:(NSString *)file;

//- (id <iMediaBrowser>)browser;
- (void)setBrowser:(id <iMediaBrowser>)browser;
- (NSString *)databasePath;

// subclasses implement this
- (iMBLibraryNode *)parseDatabase;

// extended support for subclasses that watch multiple databases
- (void)watchFile:(NSString *)file;
- (void)stopWatchingFile:(NSString *)file;

// helper method to generate an attributed string with icon and name
- (NSAttributedString *)name:(NSString *)name withImage:(NSImage *)image;

@end
