#import "IMBQuickLookController.h"
#import "QLPreviewPanel.h"

#define NSAppKitVersionNumber_SnowLeopard (1000.0)


//#pragma mark Localization
//
//#define SERVICE_BUNDLE [NSBundle bundleWithIdentifier:@"com.boinx.BXServices"]
//
//static inline NSString * LocMenuItemCloseQuickLookPanel()
//{
//	return NSLocalizedStringWithDefaultValue(
//											 @"MenuItemCloseQuickLookPanel",
//											 @"BXServices",
//											 SERVICE_BUNDLE,
//											 @"Close Quick Look",
//											 nil);
//}
//
//static inline NSString * LocMenuItemOpenQuickLookPanel()
//{
//	return NSLocalizedStringWithDefaultValue(
//											 @"MenuItemOpenQuickLookPanel",
//											 @"BXServices",
//											 SERVICE_BUNDLE,
//											 @"Open Quick Look",
//											 nil);
//}


@interface IMBQuickLookController ()
- (BOOL)_handleKeyDownEvent:(NSEvent *)inEvent;
@end


@implementation IMBQuickLookController

+ (IMBQuickLookController *)sharedController
{
	static IMBQuickLookController *sharedController = nil;
	if (!sharedController)
		sharedController = [[IMBQuickLookController alloc] init];
	return sharedController;
}

- (id)init
{
	self = [super init];
	if (!self) return nil;
	
	_available = [[NSBundle bundleWithPath:@"/System/Library/Frameworks/Quartz.framework/Frameworks/QuickLookUI.framework"] load];
	if (!_available)
	{
		_available = [[NSBundle bundleWithPath:@"/System/Library/PrivateFrameworks/QuickLookUI.framework"] load];
	}
	
	Class previewPanelClass = QLPreviewPanelClass;
	
	if (_available && QLPreviewPanelClass != Nil /*&& NSAppKitVersionNumber < NSAppKitVersionNumber_SnowLeopard*/)
	{
		[[[QLPreviewPanelClass sharedPreviewPanel] windowController] setDelegate:self];
	}
	else
	{
		NSLog(@"Could not load QuickLookUI.framework.");
	}
	
	id nextResponder = [NSApp nextResponder];
	[NSApp setNextResponder:self];
	[self setNextResponder:nextResponder];
	
	return self;
}

- (void)dealloc
{
	[_dataSource release];
	[_URLs release];
	[super dealloc];
}

- (id)dataSource
{
	return [[_dataSource retain] autorelease];
}

- (void)setDataSource:(id)inDataSource
{
	if (_dataSource != inDataSource)
	{
		id old = _dataSource;
		_dataSource = [inDataSource retain];
		[old release];
	}
}

- (void)reloadData
{
	if (_available)
	{
		id panel = [QLPreviewPanelClass sharedPreviewPanel];
		if ([panel respondsToSelector:@selector(updateController)])
			[panel updateController];
		
		id dataSource = [self dataSource];
		
		id old = _URLs;
		_URLs = [[dataSource URLsForQuickLookController:self] retain];
		[old release];
		
		if (NSAppKitVersionNumber >= NSAppKitVersionNumber_SnowLeopard)
		{
			[panel reloadData];
		}
		else
		{
			unsigned int index = 0;
			if ([dataSource respondsToSelector:@selector(currentIndexForQuickLookController:)])
			{
				index = [dataSource currentIndexForQuickLookController:self];
			}
			
			[panel setURLs:_URLs currentIndex:index preservingDisplayState:NO];
		}
	}
}

- (BOOL)isOpen
{
	return _available && [[QLPreviewPanelClass sharedPreviewPanel] isOpen];
}

- (void)update:(id)inSender
{
#pragma unused (inSender)
	
	if ([self isOpen])
		[self reloadData];
}

- (BOOL)canOpen
{
	if (_available)
	{
		[self reloadData];
		return ([_URLs count] > 0);
	}
	return NO;
}

- (BOOL)toggle
{
	id panel = [QLPreviewPanelClass sharedPreviewPanel];
	if ([panel respondsToSelector:@selector(updateController)])
		[panel updateController];
	
	if ([self isOpen])
	{
		if (NSAppKitVersionNumber >= NSAppKitVersionNumber_SnowLeopard)
			[panel close];
		else
			[panel closeWithEffect:2];
		return YES;
	}
	else if ([self canOpen])
	{
		if (NSAppKitVersionNumber >= NSAppKitVersionNumber_SnowLeopard)
			[panel makeKeyAndOrderFront:nil];
		else
			[panel makeKeyAndOrderFrontWithEffect:2];
		
		id dataSource = [self dataSource];
		if ([dataSource respondsToSelector:@selector(quickLookControllerDidDisplay:)])
			[dataSource quickLookControllerDidDisplay:self];
		return YES;
	}
	return NO;
}

- (void)toggle:(id)inSender
{
#pragma unused (inSender)
	
	[self toggle];
}

#pragma mark
#pragma mark Snow Leopard Methods

- (void)beginPreviewPanelControl:(id)panel
{
	[panel setDataSource:self];
	[panel setDelegate:self];
}

- (void)endPreviewPanelControl:(id)panel
{
	[panel setDataSource:nil];
	[panel setDelegate:nil];
}

- (NSInteger)numberOfPreviewItemsInPreviewPanel:(id)panel
{
#pragma unused (panel)
	return (_URLs ? [_URLs count] : 0);
}

- (id)previewPanel:(id)panel previewItemAtIndex:(NSInteger)index
{
#pragma unused (panel)
	
	if (index < [_URLs count])
	{
		return [_URLs objectAtIndex:index];
	}
	return nil;
}

- (BOOL)previewPanel:(id)panel handleEvent:(NSEvent *)event
{
#pragma unused (panel)
	
	if ([event type] == NSKeyDown)
	{
		return [self _handleKeyDownEvent:event];
	}
	return NO;
}

- (NSRect)previewPanel:(id)panel sourceFrameOnScreenForPreviewItem:(id)item
{
	return [self previewPanel:panel frameForURL:item];
}


#pragma mark
#pragma mark Preview Panel Delegate Methods

// A string dump of the QuickLookUI framework on Leopard revealed the following,
// which all look like delegate methods.
//		previewPanel:didChangeDisplayStateForDocumentURL:
//		previewPanel:didChangeDisplayStateForURL:
//		previewPanel:didLoadPreviewForDocumentURL:
//		previewPanel:didLoadPreviewForURL:
//		previewPanel:didShowPreviewForURL:
//		previewPanel:frameForDocumentURL:
//		previewPanel:frameForURL:
//		previewPanel:shouldHandleEvent:
//		previewPanel:shouldOpenURL:
//		previewPanel:syncDisplayState:forURL:
//		previewPanel:transitionImageForURL:frame:
//		previewPanel:willLoadPreviewForDocumentURL:
//		previewPanel:willLoadPreviewForURL:


- (NSRect)previewPanel:(NSPanel *)inPanel frameForURL:(NSURL *)inURL
{
#pragma unused (inPanel)
	
	id dataSource = [self dataSource];
	if ([dataSource respondsToSelector:@selector(quickLookController:frameForURL:)])
	{
		return [dataSource quickLookController:self frameForURL:inURL];
	}
	else if ([dataSource respondsToSelector:@selector(quickLookController:frameForSelectedItemAtIndex:)])
	{
		NSUInteger index = [_URLs indexOfObject:inURL];
		return [dataSource quickLookController:self frameForSelectedItemAtIndex:index];
	}
	else
	{
		NSLog(@"QuickLook data source <%@:%p> did not implement one of the two frame protocol methods.", NSStringFromClass([dataSource class]), dataSource);
		return NSZeroRect;
	}
}

/*!
	The quicklook panel is asking its delegate (us) if it should handle the event.
	This gives us an opportunity to handle the event and then stop the panel from doing so.
	Unfortunetly if the panel is key, it never asks about space bar and escape key down events
	and if there are multiple URLs in the array, it also doesn't tell us about left and right
	arrow keys, although we do get the corresponding key up event.
*/
- (BOOL)previewPanel:(NSPanel *)panel shouldHandleEvent:(NSEvent *)event
{
	return ![self previewPanel:panel handleEvent:event];
}


- (BOOL)_handleKeyDownEvent:(NSEvent *)inEvent
{
	BOOL keyWasHandled = NO;
	if (_available)
	{
		// give the data source an opportunity to handle the event
		id dataSource = [self dataSource];
		if (dataSource && [dataSource respondsToSelector:@selector(quickLookController:handleEvent:)])
		{
			keyWasHandled = [dataSource quickLookController:self handleEvent:inEvent];
			if (keyWasHandled)
				return YES;
		}
		
		// otherwise implement some default behaviours
		//	these are disabled because space, escape, left and right are the only keys we're never asked for!
		NSString *characters = [inEvent charactersIgnoringModifiers];
		unichar c = ([characters length] > 0) ? [characters characterAtIndex:0] : 0;
		switch (c)
		{
			case ' ':
				keyWasHandled = [self toggle];
				break;
			case 27:	// esc
				keyWasHandled = [self isOpen] && [self toggle];
				break;
			case NSLeftArrowFunctionKey:
			case NSRightArrowFunctionKey:
				if ([_URLs count] > 1 && [[QLPreviewPanelClass sharedPreviewPanel] isOpen])
				{
					if (c == NSLeftArrowFunctionKey)
						[[QLPreviewPanelClass sharedPreviewPanel] selectPreviousItem];
					else
						[[QLPreviewPanelClass sharedPreviewPanel] selectNextItem];
					keyWasHandled = YES;
				}
				break;
		}
	}
	return keyWasHandled;
}


- (BOOL)handleKeyDownEvent:(NSEvent *)inEvent
{
	return [self _handleKeyDownEvent:inEvent];
}


- (BOOL)validateQuickLookMenuItem:(NSMenuItem *)inMenuItem;
{
	if ([self isOpen])
	{
//		[inMenuItem setTitle:LocMenuItemCloseQuickLookPanel()];
		return YES;
	}
	else if ([self canOpen])
	{
//		[inMenuItem setTitle:LocMenuItemOpenQuickLookPanel()];
		return YES;
	}
	return NO;
}

@end
