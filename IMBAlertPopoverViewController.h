//**********************************************************************************************************************
//
// IMBAlertPopoverViewController.h
//
//  Author:		Peter Baumgartner, peter@baumgartner.com
//  Copyright:	©2011 by IMAGINE GbR. All rights reserved.
//	Abstract:	View conroller for alert popovers
//
//**********************************************************************************************************************


#pragma mark TYPES

typedef void(^IMBButtonBlockType)(void);


//----------------------------------------------------------------------------------------------------------------------


#pragma mark -

@interface IMBAlertPopoverViewController : NSViewController
{
	IBOutlet NSImageView* _iconView;
	IBOutlet NSTextField* _headerTextField;
	IBOutlet NSTextField* _bodyTextField;
	IBOutlet NSTextField* _footerTextField;
	IBOutlet NSButton* _button0;
	IBOutlet NSButton* _button1;
	IBOutlet NSButton* _button2;
	IBOutlet NSBox* _progressBackground;
	IBOutlet NSProgressIndicator* _progressWheel;
	
	NSImage* _icon;
	NSString* _headerString;
	NSString* _bodyString;
	NSString* _footerString;
	NSMutableArray* _buttonInfo;
	NSColor* _headerTextColor;
	NSColor* _bodyTextColor;
	NSColor* _footerTextColor;
}

@property (strong) NSImage* icon;
@property (strong) NSString* headerString;
@property (strong) NSString* bodyString;
@property (strong) NSString* footerString;

@property (strong) NSColor* headerTextColor;
@property (strong) NSColor* bodyTextColor;
@property (strong) NSColor* footerTextColor;

- (void) addButtonWithTitle:(NSString*)inTitle block:(IMBButtonBlockType)inBlock;
- (void) adjustLayout;

- (void) showProgressIndicator;
- (void) hideProgressIndicator;

@end


//----------------------------------------------------------------------------------------------------------------------
