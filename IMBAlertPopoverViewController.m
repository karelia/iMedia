//**********************************************************************************************************************
//
//  IMBAlertPopoverViewController.m
//
//  Author:		Peter Baumgartner, peter@baumgartner.com
//  Copyright:	©2011 by IMAGINE GbR. All rights reserved.
//	Abstract:	View conroller for alert popovers
//
//**********************************************************************************************************************


#pragma HEADERS

#import "IMBAlertPopoverViewController.h"


//----------------------------------------------------------------------------------------------------------------------


@implementation IMBAlertPopoverViewController

@synthesize icon = _icon;
@synthesize headerString = _headerString;
@synthesize bodyString = _bodyString;
@synthesize footerString = _footerString;

@synthesize headerTextColor = _headerTextColor;
@synthesize bodyTextColor = _bodyTextColor;
@synthesize footerTextColor = _footerTextColor;


//----------------------------------------------------------------------------------------------------------------------


- (id) initWithNibName:(NSString*)inNibName bundle:(NSBundle*)inBundle
{
	self = [super initWithNibName:inNibName bundle:inBundle];
	
	if (self)
	{
		_buttonInfo = [[NSMutableArray alloc] init];
	}
	
	return self;
}


// Cleanup...

- (void) dealloc
{
	[NSObject cancelPreviousPerformRequestsWithTarget:self];
	
	IMBRelease(_icon);
	IMBRelease(_headerString);
	IMBRelease(_bodyString);
	IMBRelease(_footerString);
	IMBRelease(_buttonInfo);
	
	IMBRelease(_headerTextColor);
	IMBRelease(_bodyTextColor);
	IMBRelease(_footerTextColor);
	
	[super dealloc];
}


//----------------------------------------------------------------------------------------------------------------------


// Calculate the optimum width of the given text field, for its current content and the proposed width...

- (NSSize) _bestSizeForTextField:(NSTextField*)inTextField width:(CGFloat)inProposedWidth
{
	// First save the current string contents...
	
	NSString* originalString = inTextField.stringValue;
	
	// Divide the string into several paragraphs at line breaks. Measure each paragraph separately, 
	// and add up the results...
	
	NSArray* paragraphs = [originalString componentsSeparatedByString:@"\n"];
	NSSize totalSize = NSZeroSize;
	
	for (NSString* paragraph in paragraphs)
	{
		// Within each paragraph measure each line separately, as soft line breaks can occur at 
		// unpredictable places due to varying word lengths...
		
		NSArray* words = [paragraph componentsSeparatedByString:@" "];
		NSUInteger wordCount = words.count;
		NSUInteger n = wordCount;
		NSSize lineSize = NSZeroSize;
		NSUInteger i1 = 0;
		
		for (NSUInteger i2=0; i2<wordCount; i2++)
		{
			NSArray* words2 = [words subarrayWithRange:NSMakeRange(i1,i2-i1+1)];
			NSString* line = [words2 componentsJoinedByString:@" "];
			inTextField.stringValue = line;
			lineSize = [inTextField intrinsicContentSize];
			
			if ((lineSize.width > inProposedWidth) && ([words2 count] > 1))
			{
				n -= i2 - i1;
				i1 = i2--;
				totalSize.height += lineSize.height;
				totalSize.width = inProposedWidth;
			}
		}
		
		if (n > 0)
		{
			totalSize.height += lineSize.height;
			totalSize.width = inProposedWidth;
		}
	}
	
	// Restore the original string...
	
	inTextField.stringValue = originalString;
	
	return totalSize;
}


- (void) adjustLayout
{
	// Get rid of contraints that IB has generated, since we cannot do it in Xcode 4.2 - and changing them
	// also doesn't seam possible...
	
	NSView* superview = _headerTextField.superview;
	NSDictionary* views = NSDictionaryOfVariableBindings(
		_iconView,
		_headerTextField,
		_bodyTextField,
		_footerTextField,
		_button0,
		_button1,
		_button2,
		_progressBackground,
		_progressWheel);

	[superview removeConstraints:superview.constraints];
	[_iconView removeConstraints:_iconView.constraints];
	[_headerTextField removeConstraints:_headerTextField.constraints];
	[_bodyTextField removeConstraints:_bodyTextField.constraints];
	[_footerTextField removeConstraints:_footerTextField.constraints];
	[_button0 removeConstraints:_button0.constraints];
	[_button1 removeConstraints:_button1.constraints];
	[_button2 removeConstraints:_button2.constraints];

	// Calculate the button sizes...
	
	CGFloat totalButtonWidth = 0.0;
	CGFloat totalButtonHeight = 0.0;
	NSSize buttonSize0 = NSZeroSize;
	NSSize buttonSize1 = NSZeroSize;
	NSSize buttonSize2 = NSZeroSize;
	NSUInteger buttonCount = _buttonInfo.count;
	
	if (buttonCount > 0)
	{
		[_button0 setHidden:NO];
		buttonSize0 = [_button0 intrinsicContentSize];
		totalButtonWidth += buttonSize0.width + 8.0;
		totalButtonHeight = MAX(totalButtonHeight,buttonSize0.height);
	}

	if (buttonCount > 1)
	{
		[_button1 setHidden:NO];
		buttonSize1 = [_button1 intrinsicContentSize];
		totalButtonWidth += buttonSize1.width + 8.0;
		totalButtonHeight = MAX(totalButtonHeight,buttonSize1.height);
	}

	if (buttonCount > 2)
	{
		[_button2 setHidden:NO];
		buttonSize2 = [_button2 intrinsicContentSize];
		totalButtonWidth += buttonSize2.width + 8.0;
		totalButtonHeight = MAX(totalButtonHeight,buttonSize2.height);
	}

	if (buttonCount > 0) totalButtonWidth -= 8.0;

	// Calculate the optimum textfield sizes (depending on their content)...
	
	NSSize headerSize = [_headerTextField intrinsicContentSize];
	NSSize bodySize = [_bodyTextField intrinsicContentSize];
	NSSize footerSize /*= [_footerTextField intrinsicContentSize]*/;
	headerSize.width += 32.0;
	
	CGFloat minWidth = MAX(220.0,totalButtonWidth);
	CGFloat maxWidth = MAX(360.0,totalButtonWidth);
	if (headerSize.width < 360.0) minWidth = MAX(minWidth,headerSize.width);
	
	CGFloat width = bodySize.width / 3.0;
	if (width < minWidth) width = minWidth;
	if (width > maxWidth) width = maxWidth;
	
	headerSize = [self _bestSizeForTextField:_headerTextField width:width];
	bodySize = [self _bestSizeForTextField:_bodyTextField width:width];
	footerSize = [self _bestSizeForTextField:_footerTextField width:width];

	if (self.headerString == nil) headerSize.height = 0.0;
	if (self.bodyString == nil) bodySize.height = 0.0;
	if (self.footerString == nil) footerSize.height = 0.0;
	
	// Horizontal layout...
	
	NSString* horizontalFormat = nil;
	
	if (self.icon)
	{
		horizontalFormat = [NSString stringWithFormat:
			@"|-10-[_iconView(32)]-14-[_headerTextField(%d@800)]-16-|",
			(int)headerSize.width];
	}
	else
	{
		horizontalFormat = [NSString stringWithFormat:
			@"|-16-[_iconView(0)][_headerTextField(%d@800)]-16-|",
			(int)headerSize.width];
	}
	
	[superview addConstraints:[NSLayoutConstraint 
		constraintsWithVisualFormat:horizontalFormat 
		options:0 
		metrics:nil 
		views:views]];

	[superview addConstraints:[NSLayoutConstraint 
		constraintsWithVisualFormat:@"[_bodyTextField(==_headerTextField)]" 
		options:0 
		metrics:nil 
		views:views]];
		
	[superview addConstraints:[NSLayoutConstraint 
		constraintsWithVisualFormat:@"[_footerTextField(==_headerTextField)]" 
		options:0 
		metrics:nil 
		views:views]];

	[superview addConstraints:[NSLayoutConstraint 
		constraintsWithVisualFormat:@"|[_progressBackground]|" 
		options:0 
		metrics:nil 
		views:views]];
	
	// Button layout...
	
	NSMutableString* buttonFormat = [NSMutableString string];

	[buttonFormat appendFormat:@"[_button0(%d)]",(int)buttonSize0.width];

	if (buttonCount > 0)
	{
		[buttonFormat appendString:@"-"];
	}

	[buttonFormat appendFormat:@"[_button1(%d)]",(int)buttonSize1.width];

	if (buttonCount > 0)
	{
		[buttonFormat appendString:@"-"];
	}

	[buttonFormat appendFormat:@"[_button2(%d)]->=16@800-|",(int)buttonSize2.width];

	[superview addConstraints:[NSLayoutConstraint 
		constraintsWithVisualFormat:buttonFormat 
		options:NSLayoutFormatAlignAllTop 
		metrics:nil 
		views:views]];
		
	// Define the Vertical layout...

	NSMutableString* verticalFormat = [NSMutableString stringWithString:@"V:|-10-"];
	[verticalFormat appendFormat:@"[_headerTextField(%d)]",(int)headerSize.height];
	[verticalFormat appendString:@"-"];
	[verticalFormat appendFormat:@"[_bodyTextField(%d)]",(int)bodySize.height];
	
	if (buttonCount > 0)
	{
		if (self.footerString)
		{
			[verticalFormat appendString:@"-12-"];
			[verticalFormat appendFormat:@"[_button0(%d)]",(int)totalButtonHeight];
			[verticalFormat appendString:@"-12-"];
			[verticalFormat appendFormat:@"[_footerTextField(%d)]",(int)footerSize.height];
			[verticalFormat appendString:@"-12-|"];
		}
		else
		{
			[verticalFormat appendString:@"-12-"];
			[verticalFormat appendFormat:@"[_button0(%d)]",(int)totalButtonHeight];
			[verticalFormat appendFormat:@"[_footerTextField(%d)]",0];
			[verticalFormat appendString:@"-16-|"];
		}
	}
	else
	{
		if (self.footerString)
		{
			[verticalFormat appendString:@"-"];
			[verticalFormat appendFormat:@"[_button0(%d)]",0];
			[verticalFormat appendFormat:@"[_footerTextField(%d)]",(int)footerSize.height];
			[verticalFormat appendString:@"-12-|"];
		}
		else
		{
			[verticalFormat appendFormat:@"[_button0(%d)]",0];
			[verticalFormat appendFormat:@"[_footerTextField(%d)]",0];
			[verticalFormat appendString:@"-12-|"];
		}
	}

	[superview addConstraints:[NSLayoutConstraint 
		constraintsWithVisualFormat:verticalFormat 
		options:NSLayoutFormatAlignAllLeft
		metrics:nil 
		views:views]];
	
	[superview addConstraints:[NSLayoutConstraint 
		constraintsWithVisualFormat:@"V:|-12-[_iconView(32)]" 
		options:0 
		metrics:nil 
		views:views]];

	[superview addConstraints:[NSLayoutConstraint 
		constraintsWithVisualFormat:@"V:|[_progressBackground]|" 
		options:0 
		metrics:nil 
		views:views]];
}


//----------------------------------------------------------------------------------------------------------------------


- (void) addButtonWithTitle:(NSString*)inTitle block:(IMBButtonBlockType)inBlock
{
	IMBButtonBlockType block = [inBlock copy];
	
	NSDictionary* buttonInfo = [NSDictionary dictionaryWithObjectsAndKeys:
		inTitle,@"title",
		block,@"block",
		nil];
	
	[block release];
		
	[_buttonInfo addObject:buttonInfo];
}


- (IBAction) buttonAction:(id)inSender
{
	NSButton* button = (NSButton*)inSender;
	IMBButtonBlockType block = [button.cell representedObject];
	block();
}


//----------------------------------------------------------------------------------------------------------------------


- (void) awakeFromNib
{
	// Set icon and strings...
	
	if (self.icon) _iconView.image = self.icon;
	if (self.headerString) _headerTextField.stringValue = self.headerString; else _headerTextField.stringValue = @"";
	if (self.bodyString) _bodyTextField.stringValue = self.bodyString; else _bodyTextField.stringValue = @"";
	if (self.footerString) _footerTextField.stringValue = self.footerString; else _footerTextField.stringValue = @"";

	// Add optional buttons...
	
	NSUInteger i = 0;
	NSButton* button = nil;
	
	for (NSDictionary* buttonInfo in _buttonInfo)
	{
		if (i == 0) button = _button0;
		else if (i == 1) button = _button1;
		else button = _button2;
		i++;
		
		[button setTitle:[buttonInfo objectForKey:@"title"]];
		[button.cell setRepresentedObject:[buttonInfo objectForKey:@"block"]];
		[button setTarget:self];
		[button setAction:@selector(buttonAction:)];
	}
	
	// Set custom colors...
	
	if (_headerTextColor) [_headerTextField setTextColor:_headerTextColor];
	if (_bodyTextColor) [_footerTextField setTextColor:_bodyTextColor];
	if (_footerTextColor) [_footerTextField setTextColor:_footerTextColor];

	// Adjust the layout according to contents...
	
	[self adjustLayout];
}


//----------------------------------------------------------------------------------------------------------------------


// Show or hide the dimming box with the progress wheel...

- (void) showProgressIndicator
{
	[_progressBackground setHidden:NO];
	[_progressWheel setUsesThreadedAnimation:YES];
	[_progressWheel startAnimation:nil];
}


- (void) hideProgressIndicator
{
	[_progressBackground setHidden:YES];
	[_progressWheel setUsesThreadedAnimation:NO];
	[_progressWheel stopAnimation:nil];
}


//----------------------------------------------------------------------------------------------------------------------


@end
