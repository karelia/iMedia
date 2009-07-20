//
//  IMBTestAppDelegate.h
//  iMedia
//
//  Created by Peter Baumgartner on 18.07.09.
//  Copyright 2009 IMAGINE GbR. All rights reserved.
//


//----------------------------------------------------------------------------------------------------------------------


#import <Cocoa/Cocoa.h>


//----------------------------------------------------------------------------------------------------------------------


@class IMBUserInterfaceController;

@interface IMBTestAppDelegate : NSObject
{
	IBOutlet IMBUserInterfaceController* ibUserInterfaceController;
}

- (IBAction) select:(id)inSender;
- (IBAction) expand:(id)inSender;
- (IBAction) update:(id)inSender;

@end


//----------------------------------------------------------------------------------------------------------------------
