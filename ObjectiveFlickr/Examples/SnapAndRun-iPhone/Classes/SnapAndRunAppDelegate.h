//
// SnapAndRunAppDelegate.h
//
// Copyright (c) 2009 Lukhnos D. Liu (http://lukhnos.org)
//
// Permission is hereby granted, free of charge, to any person
// obtaining a copy of this software and associated documentation
// files (the "Software"), to deal in the Software without
// restriction, including without limitation the rights to use,
// copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the
// Software is furnished to do so, subject to the following
// conditions:
//
// The above copyright notice and this permission notice shall be
// included in all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
// EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
// OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
// NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
// HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
// WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
// FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
// OTHER DEALINGS IN THE SOFTWARE.
//

#import <UIKit/UIKit.h>
#import "ObjectiveFlickr.h"

extern NSString *SnapAndRunShouldUpdateAuthInfoNotification;

@interface SnapAndRunAppDelegate : NSObject <UIApplicationDelegate, OFFlickrAPIRequestDelegate>
{    
    UINavigationController *viewController;
    UIWindow *window;
	
	UIActivityIndicatorView *activityIndicator;
	UIView *progressView;
	UIButton *cancelButton;
	UILabel *progressDescription;
    
    OFFlickrAPIContext *flickrContext;
	OFFlickrAPIRequest *flickrRequest;
	NSString *flickrUserName;
}

+ (SnapAndRunAppDelegate *)sharedDelegate;
- (void)setAndStoreFlickrAuthToken:(NSString *)inAuthToken secret:(NSString *)inSecret;

- (IBAction)cancelAction;

@property (nonatomic, retain) IBOutlet UINavigationController *viewController;
@property (nonatomic, retain) IBOutlet UIWindow *window;
@property (nonatomic, retain) IBOutlet UIActivityIndicatorView *activityIndicator;
@property (nonatomic, retain) IBOutlet UIView *progressView;
@property (nonatomic, retain) IBOutlet UIButton *cancelButton;
@property (nonatomic, retain) IBOutlet UILabel *progressDescription;

@property (nonatomic, readonly) OFFlickrAPIContext *flickrContext;
@property (nonatomic, retain) NSString *flickrUserName;
@end

extern NSString *SRCallbackURLBaseString;