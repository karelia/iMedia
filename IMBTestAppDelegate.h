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


#pragma mark CLASSES

@class IMBNodeViewController;
@class IMBObjectViewController;


//----------------------------------------------------------------------------------------------------------------------


@class IMBUserInterfaceController;

@interface IMBTestAppDelegate : NSObject
{
	IBOutlet NSWindow* ibWindow;
	IBOutlet IMBNodeViewController* _nodeViewController;
	IBOutlet IMBObjectViewController* _objectViewController;
}

@property (retain) IMBNodeViewController* nodeViewController;
@property (retain) IMBObjectViewController* objectViewController;

@end


//----------------------------------------------------------------------------------------------------------------------
