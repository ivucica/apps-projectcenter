/*
   GNUstep ProjectCenter - http://www.gnustep.org/experience/ProjectCenter.html

   Copyright (C) 2000-2004 Free Software Foundation

   Authors: Philippe C.D. Robert
            Serg Stoyan

   This file is part of GNUstep.

   This application is free software; you can redistribute it and/or
   modify it under the terms of the GNU General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.

   This application is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Library General Public License for more details.

   You should have received a copy of the GNU General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA.
*/

#include <AppKit/AppKit.h>

#include <ProjectCenter/PCDefines.h>
#include <ProjectCenter/PCSplitView.h>
#include <ProjectCenter/PCButton.h>

#include <ProjectCenter/PCProjectManager.h>
#include <ProjectCenter/PCProject.h>
#include <ProjectCenter/PCProjectBuilder.h>

#include <ProjectCenter/PCLogController.h>

#ifndef IMAGE
#define IMAGE(X) [NSImage imageNamed: X]
#endif

#ifndef NOTIFICATION_CENTER
#define NOTIFICATION_CENTER [NSNotificationCenter defaultCenter]
#endif

@implementation PCProjectBuilder (UserInterface)

- (void)awakeFromNib
{
  NSScrollView *errorScroll; 
  NSScrollView *scrollView2;

  [componentView retain];
  [componentView removeFromSuperview];

  /*
   * 4 build Buttons
   */
  [buildButton setToolTip:@"Build"];
//  [buildButton setImage:IMAGE(@"Build")];

  [cleanButton setToolTip:@"Clean"];
//  [cleanButton setImage:IMAGE(@"Clean")];

  [installButton setToolTip:@"Install"];
//  [installButton setImage:IMAGE(@"Install")];

  [optionsButton setToolTip:@"Options"];
//  [optionsButton setImage:IMAGE(@"Options")];

  /*
   *  Error output
   */
  errorArray = [[NSMutableArray alloc] initWithCapacity:0];
  errorString = [[NSMutableString alloc] initWithString:@""];

  errorImageColumn = [[NSTableColumn alloc] initWithIdentifier:@"ErrorImage"];
  [errorImageColumn setEditable:NO];
  [errorImageColumn setWidth:20.0];
  errorColumn = [[NSTableColumn alloc] initWithIdentifier:@"Error"];
  [errorColumn setEditable:NO];

  errorOutputTable = [[NSTableView alloc]
    initWithFrame:NSMakeRect(6,6,209,111)];
  [errorOutputTable setAllowsMultipleSelection:NO];
  [errorOutputTable setAllowsColumnReordering:NO];
  [errorOutputTable setAllowsColumnResizing:NO];
  [errorOutputTable setAllowsEmptySelection:YES];
  [errorOutputTable setAllowsColumnSelection:NO];
  [errorOutputTable setRowHeight:19.0];
  [errorOutputTable setCornerView:nil];
  [errorOutputTable setHeaderView:nil];
  [errorOutputTable addTableColumn:errorImageColumn];
  [errorOutputTable addTableColumn:errorColumn];
  [errorOutputTable setDataSource:self];
  [errorOutputTable setBackgroundColor:[NSColor colorWithDeviceRed:0.88
                                                             green:0.76 
                                                              blue:0.60 
                                                             alpha:1.0]];
  [errorOutputTable setDrawsGrid:NO];

  errorScroll = [[NSScrollView alloc] initWithFrame:NSMakeRect(0,0,464,120)];
  [errorScroll setHasHorizontalScroller:NO];
  [errorScroll setHasVerticalScroller:YES];
  [errorScroll setBorderType:NSBezelBorder];
  [errorScroll setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];

/*  errorOutput = [[NSTextView alloc] 
    initWithFrame:[[scrollView1 contentView] frame]];
  [errorOutput setRichText:NO];
  [errorOutput setEditable:NO];
  [errorOutput setSelectable:YES];
  [errorOutput setAutoresizingMask: NSViewWidthSizable | NSViewHeightSizable];
  [errorOutput setBackgroundColor:[NSColor colorWithDeviceRed:0.88
                                                        green:0.76 
                                                         blue:0.60 
                                                        alpha:1.0]];
  [errorOutput setHorizontallyResizable:NO]; 
  [errorOutput setVerticallyResizable:YES];
  [errorOutput setMinSize:NSMakeSize(0, 0)];
  [errorOutput setMaxSize:NSMakeSize(1E7, 1E7)];
  [[errorOutput textContainer] setContainerSize: 
    NSMakeSize([errorOutput frame].size.width, 1e7)];
  [[errorOutput textContainer] setWidthTracksTextView:YES];*/

  [errorScroll setDocumentView:errorOutputTable];
  RELEASE(errorOutputTable);

  /*
   *  Log output
   */
  scrollView2 = [[NSScrollView alloc] 
    initWithFrame:NSMakeRect (0, 0, 480, 133)];
  [scrollView2 setHasHorizontalScroller:NO];
  [scrollView2 setHasVerticalScroller:YES];
  [scrollView2 setBorderType: NSBezelBorder];
  [scrollView2 setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];

  logOutput = [[NSTextView alloc] 
    initWithFrame:[[scrollView2 contentView] frame]];
  [logOutput setRichText:NO];
  [logOutput setEditable:NO];
  [logOutput setSelectable:YES];
  [logOutput setAutoresizingMask: NSViewWidthSizable | NSViewHeightSizable];
  [logOutput setBackgroundColor: [NSColor lightGrayColor]];
  [[logOutput textContainer] setWidthTracksTextView:YES];
  [[logOutput textContainer] setHeightTracksTextView:YES];
  [logOutput setHorizontallyResizable:NO];
  [logOutput setVerticallyResizable:YES];
  [logOutput setMinSize:NSMakeSize (0, 0)];
  [logOutput setMaxSize:NSMakeSize (1E7, 1E7)];
  [[logOutput textContainer] setContainerSize: 
    NSMakeSize ([logOutput frame].size.width, 1e7)];
  [[logOutput textContainer] setWidthTracksTextView:YES];

  [scrollView2 setDocumentView:logOutput];
  RELEASE(logOutput);

  /*
   * Split view
   */
  [split addSubview:errorScroll];
  RELEASE (errorScroll);
  [split addSubview:scrollView2];
  RELEASE (scrollView2);

//  [split adjustSubviews];
//  [componentView addSubview:split];
//  RELEASE (split);
}

- (void) _createOptionsPanel
{
  NSView      *cView = nil;
  NSTextField *textField = nil;

  optionsPanel = [[NSPanel alloc] 
    initWithContentRect: NSMakeRect (100, 100, 300, 120)
              styleMask: NSTitledWindowMask | NSClosableWindowMask
	        backing: NSBackingStoreBuffered
		  defer: YES];
  [optionsPanel setDelegate: self];
  [optionsPanel setReleasedWhenClosed: NO];
  [optionsPanel setTitle: @"Build Options"];
  cView = [optionsPanel contentView];

  // Args
  textField = [[NSTextField alloc] initWithFrame: NSMakeRect (8,91,60,21)];
  [textField setAlignment: NSRightTextAlignment];
  [textField setBordered: NO];
  [textField setEditable: NO];
  [textField setBezeled: NO];
  [textField setDrawsBackground: NO];
  [textField setStringValue: @"Arguments:"];
  [cView addSubview: textField];
  
  RELEASE (textField);

  // Args message
  buildTargetArgsField = [[NSTextField alloc]
    initWithFrame: NSMakeRect (70, 91, 220, 21)];
  [buildTargetArgsField setAlignment: NSLeftTextAlignment];
  [buildTargetArgsField setBordered: NO];
  [buildTargetArgsField setEditable: YES];
  [buildTargetArgsField setBezeled: YES];
  [buildTargetArgsField setDrawsBackground: YES];
  [buildTargetArgsField setStringValue: @""];
  [buildTargetArgsField setDelegate: self];
  [buildTargetArgsField setTarget: self];
  [buildTargetArgsField setAction: @selector (setArguments:)];
  [cView addSubview: buildTargetArgsField];

//  RELEASE (buildTargetArgsField);

  // Host
  textField = [[NSTextField alloc] initWithFrame: NSMakeRect (8,67,60,21)];
  [textField setAlignment: NSRightTextAlignment];
  [textField setBordered: NO];
  [textField setEditable: NO];
  [textField setBezeled: NO];
  [textField setDrawsBackground: NO];
  [textField setStringValue: @"Host:"];
  [cView addSubview: textField];

  RELEASE (textField);

  // Host message
  buildTargetHostField = [[NSTextField alloc] 
    initWithFrame: NSMakeRect (70, 67, 220, 21)];
  [buildTargetHostField setAlignment: NSLeftTextAlignment];
  [buildTargetHostField setBordered: NO];
  [buildTargetHostField setEditable: YES];
  [buildTargetHostField setBezeled: YES];
  [buildTargetHostField setDrawsBackground: YES];
  [buildTargetHostField setStringValue: @"localhost"];
  [buildTargetHostField setDelegate: self];
  [buildTargetHostField setTarget: self];
  [buildTargetHostField setAction: @selector (setHost:)];
  [cView addSubview: buildTargetHostField];
  
//  RELEASE (buildTargetArgsField);

  // Target
  textField = [[NSTextField alloc]
    initWithFrame: NSMakeRect (8, 40, 60, 21)];
  [textField setAlignment: NSRightTextAlignment];
  [textField setBordered: NO];
  [textField setBezeled: NO];
  [textField setEditable: NO];
  [textField setSelectable: NO];
  [textField setDrawsBackground: NO];
  [textField setStringValue: @"Target:"];
  [textField setAutoresizingMask: (NSViewMaxXMargin | NSViewMinYMargin)];
  [cView addSubview: textField];

  RELEASE(textField);

  // Target popup
  popup = [[NSPopUpButton alloc] 
    initWithFrame: NSMakeRect (70, 40, 220, 21)];
  [popup addItemWithTitle: @"Default"];
  [popup addItemWithTitle: @"Debug"];
  [popup addItemWithTitle: @"Profile"];
  [popup addItemWithTitle: @"Tarball"];
  [popup addItemWithTitle: @"RPM"];
  [popup setTarget: self];
  [popup setAction: @selector (popupChanged:)];
  [popup setAutoresizingMask: (NSViewMaxXMargin | NSViewMinYMargin)];
  [cView addSubview: popup];

  RELEASE (popup);
}

@end

@implementation PCProjectBuilder

- (id)initWithProject:(PCProject *)aProject
{
  NSAssert(aProject, @"No project specified!");

//  PCLogInfo(self, @"initWithProject %@", [aProject projectName]);
  
  if ((self = [super init]))
    {
      currentProject = aProject;
      buildTarget = [[NSMutableString alloc] initWithString:@"Default"];
      buildArgs = [[NSMutableArray array] retain];
      postProcess = NULL;
      makeTask = nil;
      _isBuilding = NO;
      _isCleaning = NO;

      makePath = [[NSUserDefaults standardUserDefaults] objectForKey:BuildTool];

      if ([NSBundle loadNibNamed:@"Builder" owner:self] == NO)
	{
	  PCLogError(self, @"error loading Builder NIB file!");
	  return nil;
	}
    }

  return self;
}

- (void)dealloc
{
#ifdef DEVELOPMENT
  NSLog (@"PCProjectBuilder: dealloc");
#endif

  [buildTarget release];
  [buildArgs release];
  [makePath release];

//  PCLogInfo(self, @"componentView RC: %i", [componentView retainCount]);
//  PCLogInfo(self, @"RC: %i", [self retainCount]);
  [componentView release];
  [errorArray release];
  [errorString release];

  [super dealloc];
}

- (NSView *)componentView
{
  return componentView;
}

// --- Accessory
- (BOOL)isBuilding
{
  return _isBuilding;
}

- (BOOL)isCleaning
{
  return _isCleaning;
}

- (void)performStartBuild
{
  if (!_isBuilding && !_isCleaning)
    {
      [buildButton performClick:self];
    }
}

- (void)performStartClean
{
  if (!_isCleaning && !_isBuilding)
    {
      [cleanButton performClick:self];
    }
}

- (void)performStopBuild
{
  if (_isBuilding)
    {
      [buildButton performClick:self];
    }
  else if (_isCleaning)
    {
      [cleanButton performClick:self];
    }
}

// --- GUI Actions
- (void)startBuild:(id)sender
{
  NSString *tFString = [targetField stringValue];
  NSArray  *tFArray = [tFString componentsSeparatedByString:@" "];

  if ([self stopBuild:self] == YES)
    {// We've just stopped build process
      return;
    }
  [buildTarget setString:[tFArray objectAtIndex:0]];

  // Set build arguments
  if ([buildTarget isEqualToString:@"Debug"])
    {
      [buildArgs addObject:@"debug=yes"];
    }
  else if ([buildTarget isEqualToString:@"Profile"])
    {
      [buildArgs addObject:@"profile=yes"];
      [buildArgs addObject:@"static=yes"];
    }
  else if ([buildTarget isEqualToString:@"Tarball"])
    {
      [buildArgs addObject:@"dist"];
    }

  currentEL = ELNone;
  lastEL = ELNone;
  nextEL = ELNone;
  lastIndentString = @"";

  statusString = [NSString stringWithString:@"Building..."];
  [buildTarget setString:@"Build"];
  [cleanButton setEnabled:NO];
  [installButton setEnabled:NO];
  [self build:self];
  _isBuilding = YES;
}

- (BOOL)stopBuild:(id)sender
{
  // [makeTask isRunning] doesn't work here.
  // "waitpid 7045, result -1, error No child processes" is printed.
  if (makeTask)
    {
      PCLogStatus(self, @"task will terminate");
      NS_DURING
	{
	  [makeTask terminate];
	}
      NS_HANDLER
	{
	  return NO;
	}
      NS_ENDHANDLER
      return YES;
    }

  return NO;
}

- (void)startClean:(id)sender
{
  if ([[[[NSUserDefaults standardUserDefaults] dictionaryRepresentation]
      objectForKey:PromptOnClean] isEqualToString:@"YES"])
    {
      if (NSRunAlertPanel(@"Clean Project?",
			  @"Do you really want to clean project '%@'?",
			  @"Yes", @"No", nil, [currentProject projectName])
	  == NSAlertAlternateReturn)
	{
	  [cleanButton setState:NSOffState];
	  return;
	}
    }
  statusString = [NSString stringWithString:@"Cleaning..."];
  [buildTarget setString:@"Clean"];
  [buildArgs addObject:@"clean"];
  [buildButton setEnabled:NO];
  [installButton setEnabled:NO];
  [self build:self];
  _isCleaning = YES;
}

- (void)startInstall:(id)sender
{
  [buildTarget setString:@"Install"];
  statusString = [NSString stringWithString:@"Installing..."];
  [buildArgs addObject:@"install"];
  [buildButton setEnabled:NO];
  [cleanButton setEnabled:NO];
  [self build:self];
}

- (void)showOptionsPanel:(id)sender
{
  if (!optionsPanel)
    {
      [self _createOptionsPanel];
    }
  [optionsPanel orderFront:nil];
}

// --- Actions
- (void)build:(id)sender
{
  NSPipe       *logPipe;
  NSPipe       *errorPipe;
//  NSDictionary *env = [[NSProcessInfo processInfo] environment];

  //TODO: Support build options!!!
  //NSDictionary        *optionDict = [currentProject buildOptions];

  // Checking prerequisites
  if ([currentProject isProjectChanged])
    {
      if (NSRunAlertPanel(@"Project Changed!",
			  @"Should it be saved first?",
			  @"Yes", @"No", nil) == NSAlertDefaultReturn) 
	{
	  [currentProject save];
	}
    }
  else
    {
      // Synchronize PC.project and generated files just for case
      [currentProject save];
    }

  // Prepearing to building
  logPipe = [NSPipe pipe];
  readHandle = [logPipe fileHandleForReading];
  [readHandle waitForDataInBackgroundAndNotify];

  [NOTIFICATION_CENTER addObserver:self 
                          selector:@selector(logStdOut:)
			      name:NSFileHandleDataAvailableNotification
			    object:readHandle];

  errorPipe = [NSPipe pipe];
  errorReadHandle = [errorPipe fileHandleForReading];
  [errorReadHandle waitForDataInBackgroundAndNotify];

  [NOTIFICATION_CENTER addObserver:self 
                          selector:@selector(logErrOut:) 
			      name:NSFileHandleDataAvailableNotification
			    object:errorReadHandle];

  [buildStatusField setStringValue:statusString];

  // Run make task
  [logOutput setString:@""];
//  [errorOutput setString:@""];
  [errorArray removeAllObjects];
  [errorOutputTable reloadData];

  [NOTIFICATION_CENTER addObserver:self 
                          selector:@selector(buildDidTerminate:) 
			      name:NSTaskDidTerminateNotification
			    object:nil];

  makeTask = [[NSTask alloc] init];
  [makeTask setArguments:buildArgs];
  [makeTask setCurrentDirectoryPath:[currentProject projectPath]];
  [makeTask setLaunchPath:makePath];

  [makeTask setStandardOutput:logPipe];
  [makeTask setStandardError:errorPipe];

  NS_DURING
    {
      [makeTask launch];
    }
  NS_HANDLER
    {
      NSRunAlertPanel(@"Problem Launching Build Tool",
		      [localException reason],
		      @"OK", nil, nil, nil);
		      
      //Clean up after task is terminated
      [[NSNotificationCenter defaultCenter] 
	postNotificationName:NSTaskDidTerminateNotification
	              object:makeTask];
    }
  NS_ENDHANDLER
}

- (void)buildDidTerminate:(NSNotification *)aNotif
{
  int status;

  if ([aNotif object] != makeTask)
    {
      return;
    }

  NSLog(@"task did terminate");

//  [NOTIFICATION_CENTER removeObserver:self];

  [NOTIFICATION_CENTER removeObserver:self 
			         name:NSTaskDidTerminateNotification
			       object:nil];

  // If task was not launched catch exception
  NS_DURING
    {
      status = [makeTask terminationStatus];
    }
  NS_HANDLER
    {
      status = 1;
    }
  NS_ENDHANDLER
  
  if (status == 0)
    {
      [self logString: 
	[NSString stringWithFormat:@"=== %@ succeeded!", buildTarget] 
	                     error:NO
			   newLine:NO];
      [buildStatusField setStringValue:[NSString stringWithFormat: 
	@"%@ - %@ succeeded...", [currentProject projectName], buildTarget]];
    } 
  else
    {
      [self logString: 
	[NSString stringWithFormat:@"=== %@ terminated!", buildTarget]
	                     error:NO
			   newLine:NO];
      [buildStatusField setStringValue:[NSString stringWithFormat: 
	@"%@ - %@ terminated...", [currentProject projectName], buildTarget]];
    }

  // Rstore buttons state
  if ([buildTarget isEqualToString:@"Build"])
    {
      [buildButton setState:NSOffState];
      [cleanButton setEnabled:YES];
      [installButton setEnabled:YES];
    }
  else if ([buildTarget isEqualToString:@"Clean"])
    {
      [cleanButton setState:NSOffState];
      [buildButton setEnabled:YES];
      [installButton setEnabled:YES];
    }
  else if ([buildTarget isEqualToString:@"Install"])
    {
      [installButton setState:NSOffState];
      [buildButton setEnabled:YES];
      [cleanButton setEnabled:YES];
    }

  [buildArgs removeAllObjects];
  [buildTarget setString:@"Default"];

  RELEASE(makeTask);
  makeTask = nil;

  // Run post process if configured
/*  if (status && postProcess)
    {
      [self performSelector:postProcess];
      postProcess = NULL;
    }*/

  _isBuilding = NO;
  _isCleaning = NO;
}

- (void)popupChanged:(id)sender
{
  NSString *target = [targetField stringValue];

  target = [NSString stringWithFormat: 
            @"%@ with args ' %@ '", 
            [popup titleOfSelectedItem], 
            [buildTargetArgsField stringValue]];

  [targetField setStringValue: target];
}

- (void)logStdOut:(NSNotification *)aNotif
{
  NSData *data;

//  NSLog(@"logStdOut");

  if ((data = [readHandle availableData]) && [data length] > 0)
    {
      [self logData:data error:NO];
    }

  if (makeTask)
    {
      [readHandle waitForDataInBackgroundAndNotify];
    }
  else
    {
      [NOTIFICATION_CENTER removeObserver:self 
			             name:NSFileHandleDataAvailableNotification
			           object:readHandle];
    }
}

- (void)logErrOut:(NSNotification *)aNotif
{
  NSData *data;

//  NSLog(@"logErrOut");
  
//  if ((data = [errorReadHandle availableData]) && [data length] > 1)
  if ((data = [errorReadHandle availableData]))
    {
      [self logData:data error:YES];
    }

  if (makeTask)
    {
      [errorReadHandle waitForDataInBackgroundAndNotify];
    }
  else
    {
      [NOTIFICATION_CENTER removeObserver:self 
			             name:NSFileHandleDataAvailableNotification
			           object:errorReadHandle];
    }
}

- (void)copyPackageTo:(NSString *)path
{
  NSString *source = nil;
  NSString *dest = nil;
  NSString *rpm = nil;
  NSString *srcrpm = nil;

  // Copy the rpm files to the source directory
  if (source) 
  {
    [[NSFileManager defaultManager] copyPath:srcrpm toPath:dest handler:nil];
    [[NSFileManager defaultManager] copyPath:rpm    toPath:dest handler:nil];
  }
}

@end

@implementation PCProjectBuilder (BuildLogging)

- (void)logString:(NSString *)string
            error:(BOOL)yn
{
  [self logString:string error:yn newLine:NO];
}

- (void)logString:(NSString *)str
            error:(BOOL)yn
	  newLine:(BOOL)newLine
{
//  NSTextView *out = (yn) ? errorOutput : logOutput;
  NSTextView *out = logOutput;

  [out replaceCharactersInRange:
    NSMakeRange([[out string] length],0) withString:str];

  if (newLine)
    {
      [out replaceCharactersInRange:
	NSMakeRange([[out string] length], 0) withString:@"\n"];
    }
  else
    {
      [out replaceCharactersInRange:
	NSMakeRange([[out string] length], 0) withString:@" "];
    }

  [out scrollRangeToVisible:NSMakeRange([[out string] length], 0)];
  [out setNeedsDisplay:YES];
}

- (void)logData:(NSData *)data
          error:(BOOL)yn
{
  NSString *s = nil;

  s = [[NSString alloc] initWithData:data 
                            encoding:[NSString defaultCStringEncoding]];
			    
  if (yn)
    {
      [self logErrorString:s];
    }
  else
    {
      [self logString:s error:yn newLine:NO];
    }

  RELEASE(s);
}

@end

@implementation PCProjectBuilder (ErrorLogging)

- (void)logErrorString:(NSString *)string
{
  NSRange newLineRange;
  NSRange lineRange;
  NSArray *items;

  // Process new data
  lineRange.location = 0;
  [errorString appendString:string];
  while (newLineRange.location != NSNotFound)
    {
      newLineRange = [errorString rangeOfString:@"\n"];
/*      NSLog(@"Line(%i) new line range: %i,%i for string\n<--|%@|-->", 
	    [errorString length],
	    newLineRange.location, newLineRange.length, 
	    errorString);*/

      if (newLineRange.location < [errorString length])
	{
	  NSLog(@"<------%@------>", errorString);

	  lineRange.length = newLineRange.location+1;
	  string = [errorString substringWithRange:lineRange];
	  items = [self parseErrorLine:string];
	  if (items)
	    {
	      [self addItems:items];
	    }
	  [errorString deleteCharactersInRange:lineRange];
	}
      else
	{
	  newLineRange.location = NSNotFound;
	  continue;
	}
    }
}

- (void)addItems:(NSArray *)items
{
  [errorArray addObjectsFromArray:items];
  [errorOutputTable reloadData];
  [errorOutputTable scrollRowToVisible:[errorArray count]-1];
}

- (NSString *)lineTail:(NSString*)line afterString:(NSString*)string
{
  NSRange substrRange;

  substrRange = [line rangeOfString:string];
/*  NSLog(@"In function ':%i:%i", 
	substrRange.location, substrRange.length);*/
  substrRange.location += substrRange.length;
  substrRange.length = [line length] - (substrRange.location);
/*  NSLog(@"In function ':%i:%i", 
	substrRange.location, substrRange.length);*/

  return [line substringWithRange:substrRange];
}

- (NSArray *)parseErrorLine:(NSString *)string
{
  NSArray             *components = [string componentsSeparatedByString:@":"];
  NSString            *file = [NSString stringWithString:@""];
  NSString            *includedFile = [NSString stringWithString:@""];
  NSString            *position = [NSString stringWithString:@"{x=0; y=0}"];
  NSString            *type = [NSString stringWithString:@""];
  NSString            *message = [NSString stringWithString:@""];
  NSMutableArray      *items = [NSMutableArray arrayWithCapacity:1];
  NSMutableDictionary *errorItem;
  NSString            *indentString = @"\t";
  NSString            *lastFile = @"";
  NSString            *lastIncludedFile = @"";

  lastEL = currentEL;

  if (lastEL == ELFile) NSLog(@"+++ELFile");
  if (lastEL == ELFunction) NSLog(@"+++ELFunction");
  if (lastEL == ELIncluded) NSLog(@"+++ELIncluded");
  if (lastEL == ELError) NSLog(@"+++ELError");
  if (lastEL == ELNone) NSLog(@"+++ELNone");

  if ([errorArray count] > 0)
    {
      lastFile = [[errorArray lastObject] objectForKey:@"File"];
//      if (!lastFile) lastFile = @"";
      lastIncludedFile = [[errorArray lastObject] objectForKey:@"IncludedFile"];
//      if (!lastIncludedFile) lastIncludedFile = @"";
    }

  if ([string rangeOfString:@"In file included from "].location != NSNotFound)
    {
      NSLog(@"In file included from ");
      currentEL = ELIncluded;
      file = [self lineTail:[components objectAtIndex:0]
		afterString:@"In file included from "];
      if ([file isEqualToString:lastFile])
	{
	  return nil;
	}
      position = [NSString stringWithFormat:@"{x=0; y=%f}", 
	       [components objectAtIndex:1]];
      message = [components objectAtIndex:0];
    }
  else if ([string rangeOfString:@"In function '"].location != NSNotFound)
    {
      file = [components objectAtIndex:0];
      message = [self lineTail:string afterString:@"In function "];
      currentEL = ELFunction;
    }
  else if ([string rangeOfString:@" At top level:"].location != NSNotFound)
    {
      currentEL = ELFile;
      return nil;
    }
  else if ([components count] > 2)
    {
      unsigned typeIndex;
      NSString *substr;

      // file and includedFile
      file = [components objectAtIndex:0];
      if (lastEL == ELIncluded || [file isEqualToString:lastIncludedFile])
	{// first message after "In file included from"
	  NSLog(@"Inlcuded File: %@", file);
	  includedFile = file;
	  file = lastFile;
	  currentEL = ELIncludedError;
	}
      else
	{
	  currentEL = ELError;
	}

      // type
      if ((typeIndex = [components indexOfObject:@" warning"]) != NSNotFound)
	{
	  type = [components objectAtIndex:typeIndex];
	}
      else if ((typeIndex = [components indexOfObject:@" error"]) != NSNotFound)
	{
	  type = [components objectAtIndex:typeIndex];
	}
      // position
      if (typeIndex == 2) // :line:
	{
	  position = [NSString stringWithFormat:@"{x=0; y=%f}", 
		   [components objectAtIndex:1]];
	}
      else if (typeIndex == 3) // :line:column:
	{
	  position = [NSString stringWithFormat:@"{x=%f; y=%f}", 
	      	   [components objectAtIndex:2], [components objectAtIndex:1]];
	}
      // message
      substr = [NSString stringWithFormat:@"%@:", type];
      message = [self lineTail:string afterString:substr];
    }
  else
    {
      return nil;
    }

  // Insert indentation
  if (currentEL == ELError)
    {
      if (lastEL == ELFunction)
	{
	  indentString = @"\t\t";
	}
      else if (lastEL == ELError)
	{
	  indentString = [NSString stringWithString:lastIndentString];
	}
    }
  else if (currentEL == ELIncluded)
    {
      indentString = @"";
    }
  else if (currentEL == ELIncludedError)
    {
      indentString = @"\t\t";
    }

  message = [NSString stringWithFormat:@"%@%@", indentString, message];
  lastIndentString = [indentString copy];

  // Create array items
  if ((lastEL == ELIncluded 
       || ![includedFile isEqualToString:@""])
       && ![includedFile isEqualToString:lastIncludedFile])
    {
//      NSString *includedMessage;

      NSLog(@"lastEL == ELIncluded");

/*      includedMessage = [NSString stringWithFormat:@"\t%@(%@)", 
		      includedFile, file];*/

      NSLog(@"Included: %@ != %@", includedFile, lastIncludedFile);
      errorItem = [NSMutableDictionary dictionaryWithCapacity:1];
      [errorItem setObject:@"" forKey:@"ErrorImage"];
      [errorItem setObject:[file copy] forKey:@"File"];
      [errorItem setObject:[includedFile copy] forKey:@"IncludedFile"];
      [errorItem setObject:@"" forKey:@"Position"];
      [errorItem setObject:@"" forKey:@"Type"];
      [errorItem setObject:[includedFile copy] forKey:@"Error"];

      [items addObject:errorItem];
    }
  else if ((lastEL == ELNone 
	    || ![file isEqualToString:lastFile] 
	    || lastEL == ELIncludedError)
	   && currentEL != ELIncluded
	   && currentEL != ELIncludedError)
    {
      NSLog(@"lastEL == ELNone (%@)", includedFile);
      NSLog(@"File: %@ != %@", file, lastFile);
      errorItem = [NSMutableDictionary dictionaryWithCapacity:1];
      [errorItem setObject:@"" forKey:@"ErrorImage"];
      [errorItem setObject:[file copy] forKey:@"File"];
      [errorItem setObject:[includedFile copy] forKey:@"IncludedFile"];
      [errorItem setObject:@"" forKey:@"Position"];
      [errorItem setObject:@"" forKey:@"Type"];
      [errorItem setObject:[file copy] forKey:@"Error"];

      [items addObject:errorItem];
    }

  errorItem = [NSMutableDictionary dictionaryWithCapacity:1];
  [errorItem setObject:@"" forKey:@"ErrorImage"];
  [errorItem setObject:[file copy] forKey:@"File"];
  [errorItem setObject:[includedFile copy] forKey:@"IncludedFile"];
  [errorItem setObject:[position copy] forKey:@"Position"];
  [errorItem setObject:[type copy] forKey:@"Type"];
  [errorItem setObject:[message copy] forKey:@"Error"];

  NSLog(@"Parsed message: %@ (%@)", message, includedFile);

  [items addObject:errorItem];

  return items;
}

- (int)numberOfRowsInTableView:(NSTableView *)aTableView
{
  if (errorArray != nil && aTableView == errorOutputTable)
    {
      return [errorArray count];
    }

  return 0;
}
    
- (id)            tableView:(NSTableView *)aTableView
  objectValueForTableColumn:(NSTableColumn *)aTableColumn
                        row:(int)rowIndex
{
  NSDictionary *errorItem;

  if (errorArray != nil && aTableView == errorOutputTable)
    {
      id dataCell = [aTableColumn dataCellForRow:rowIndex];

      [dataCell setBackgroundColor:[NSColor whiteColor]];
      errorItem = [errorArray objectAtIndex:rowIndex];

      return [errorItem objectForKey:[aTableColumn identifier]];
    }

  return nil;
}
  
@end
