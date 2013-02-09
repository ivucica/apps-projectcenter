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

#import <AppKit/AppKit.h>

#import <ProjectCenter/PCDefines.h>
#import <ProjectCenter/PCProject.h>
#import <ProjectCenter/PCProjectManager.h>
#import <ProjectCenter/PCProjectLauncher.h>
#import <ProjectCenter/PCBundleManager.h>
#import <ProjectCenter/PCButton.h>
#import <ProjectCenter/PCLogController.h>

#import "Modules/Preferences/Misc/PCMiscPrefs.h"

#ifndef NOTIFICATION_CENTER
#define NOTIFICATION_CENTER [NSNotificationCenter defaultCenter]
#endif

#ifndef IMAGE
#define IMAGE(X) [[[NSImage alloc] initWithContentsOfFile:[[NSBundle mainBundle] pathForImageResource:(X)]] autorelease]
#endif

enum {
    DEBUG_DEFAULT_TARGET = 1,
    DEBUG_DEBUG_TARGET   = 2
};

@protocol Terminal

- (BOOL)terminalRunProgram:(NSString *)path
             withArguments:(NSArray *)args
               inDirectory:(NSString *)directory
                properties:(NSDictionary *)properties;

@end

@implementation PCProjectLauncher (UserInterface)

- (void)_createComponentView
{
  NSScrollView       *scrollView; 
  NSString           *string;
  NSAttributedString *attributedString;

  componentView = [[NSBox alloc] initWithFrame:NSMakeRect(8,-1,464,322)];
  [componentView setTitlePosition:NSNoTitle];
  [componentView setBorderType:NSNoBorder];
  [componentView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
  [componentView setContentViewMargins: NSMakeSize(0.0,0.0)];

  /*
   * Top buttons
   */
  runButton = [[PCButton alloc] initWithFrame: NSMakeRect(0,271,43,43)];
  [runButton setTitle: @"Run"];
  [runButton setImage: IMAGE(@"Run")];
  [runButton setAlternateImage: IMAGE(@"Stop")];
  [runButton setTarget: self];
  [runButton setAction: @selector(run:)];
  [runButton setAutoresizingMask: (NSViewMaxXMargin | NSViewMinYMargin)];
  [runButton setButtonType: NSToggleButton];
  [componentView addSubview: runButton];
  RELEASE (runButton);

  debugButton = [[PCButton alloc] initWithFrame: NSMakeRect(44,271,43,43)];
  [debugButton setTitle: @"Debug"];
  [debugButton setImage: IMAGE(@"Debug")];
  [debugButton setAlternateImage: IMAGE(@"Stop")];
  [debugButton setTarget: self];
  [debugButton setAction: @selector(debug:)];
  [debugButton setAutoresizingMask: (NSViewMaxXMargin | NSViewMinYMargin)];
  [debugButton setButtonType: NSToggleButton];
  [componentView addSubview: debugButton];
  RELEASE (debugButton);

  /*
   *
   */
  scrollView = [[NSScrollView alloc] initWithFrame:NSMakeRect (0,0,464,255)];

  [scrollView setHasHorizontalScroller:NO];
  [scrollView setHasVerticalScroller:YES];
  [scrollView setBorderType: NSBezelBorder];
  [scrollView setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];

  stdOut=[[NSTextView alloc] initWithFrame:[[scrollView contentView] frame]];

  [stdOut setMinSize: NSMakeSize(0, 0)];
  [stdOut setMaxSize: NSMakeSize(1e7, 1e7)];
  [stdOut setRichText:YES];
  [stdOut setEditable:NO];
  [stdOut setSelectable:YES];
  [stdOut setVerticallyResizable: YES];
  [stdOut setHorizontallyResizable: NO];
  [stdOut setAutoresizingMask: NSViewWidthSizable | NSViewHeightSizable];
  [[stdOut textContainer] setWidthTracksTextView:YES];
  [[stdOut textContainer] setContainerSize:
    NSMakeSize([stdOut frame].size.width, 1e7)];

  // Font
  string  = @"=== Launcher ready ===";
  attributedString = 
    [[NSAttributedString alloc] initWithString:string 
                                    attributes:textAttributes];
  [[stdOut textStorage] setAttributedString:attributedString];

  [scrollView setDocumentView:stdOut];
  RELEASE (stdOut);

  [componentView addSubview: scrollView];
  RELEASE(scrollView);
}

@end

@implementation PCProjectLauncher

- (id)initWithProject:(PCProject *)aProject
{
  NSAssert (aProject, @"No project specified!");

  if ((self = [super init]))
    {
      NSFont *font = [NSFont userFixedPitchFontOfSize: 10.0];

      project = aProject;

      textAttributes = 
	[NSDictionary dictionaryWithObject:font forKey:NSFontAttributeName];
      [textAttributes retain];
    }

  return self;
}

- (void)dealloc
{
#ifdef DEVELOPMENT
  NSLog (@"PCProjectLauncher: dealloc");
#endif
  RELEASE (componentView);
  RELEASE (textAttributes);
  RELEASE (debugger);

  [super dealloc];
}

- (NSView *)componentView;
{
  if (!componentView)
    {
      [self _createComponentView];
    }

  return componentView;
}

- (BOOL)isRunning
{
  return _isRunning;
}

- (BOOL)isDebugging
{
  return _isDebugging;
}

- (void)performRun
{
  if (!_isRunning && !_isDebugging)
    {
      [runButton performClick:self];
    }
}

- (void)performDebug
{
  if (!_isRunning && !_isDebugging)
    {
      [debugButton performClick:self];
    }
}

- (void)debug:(id)sender
{
  NSString        *projectName = [project projectName];
  NSString        *fp = nil;
  NSString        *gdbPath = nil;
  NSFileManager   *fm = [NSFileManager defaultManager];
  PCBundleManager *bundleManager = [[project projectManager] bundleManager];

  // Check if project type is executable
  if (![project isExecutable])
    {
      NSRunAlertPanel(@"Debug",
		      @"The project is not executable",
		      @"Close", nil, nil, nil);
      [debugButton setState:NSOffState];
      return;
    }


  /* We try in the order:
   *  xxx.debug/xxx (gnustep-make v1, application),
   *  xxx.app/xxx (gnustep-make v1 and v2, application),
   *  obj/xxx (gnustep-make v1 and v2, tool).
   */
  fp = [project projectPath];
  fp = [fp stringByAppendingPathComponent: [projectName stringByAppendingPathExtension: @"debug"]];
  fp = [fp stringByAppendingPathComponent: projectName];

  if (! [fm isExecutableFileAtPath: fp])
    {
      fp = [project projectPath];
      fp = [fp stringByAppendingPathComponent: [projectName stringByAppendingPathExtension: @"app"]];
      fp = [fp stringByAppendingPathComponent: projectName];

      if (! [fm isExecutableFileAtPath: fp])
	{
	  fp = [project projectPath];
	  fp = [fp stringByAppendingPathComponent: @"obj"];
	  fp = [fp stringByAppendingPathComponent: projectName];
	}
    }

  if ([fm isExecutableFileAtPath:fp] == NO)
    {
      NSRunAlertPanel(@"Debug",
		      @"No executable! Please build the project first.",
		      @"Close",nil,nil);
      [debugButton setState:NSOffState];
      return;
    }


  // Debugger
  gdbPath = [[[project projectManager] prefController] stringForKey:Debugger];
  if (gdbPath == nil)
    {
      gdbPath = @"/usr/bin/gdb";
    }

  if ([fm isExecutableFileAtPath:gdbPath] == NO)
    {
      NSRunAlertPanel(@"Debug",
		      @"Specified debugger `%@` cannot be executed!",
		      @"Close",nil,nil,gdbPath);
      [debugButton setState:NSOffState];
      return;
    }
    

  // Debugger
  debugger = [bundleManager objectForBundleType: @"debugger"
			    protocol: @protocol(CodeDebugger)
			    fileName: [fp stringByDeletingLastPathComponent]];
  [debugger debugExecutableAtPath: fp
	    withDebugger: gdbPath];

  // turn debug button off...
  // [debugButton setState:NSOffState];
}

- (void)run:(id)sender
{
  NSMutableArray  *args = [[NSMutableArray alloc] init];
  NSPipe          *logPipe;
  NSPipe          *errorPipe;
  NSString        *executablePath;

  executablePath = [NSMutableString stringWithString:[project projectPath]];

  // Check if project type is executable
  if ([project isExecutable])
    {
      NSString *prjType;

      prjType = [project projectTypeName];
      NSLog(@"project is executable");
      if ([prjType isEqualToString: @"Application"])
	{
          /* MyApplication.app/MyApplication */
          executablePath = [executablePath stringByAppendingPathComponent:[project projectName]];
          executablePath = [executablePath stringByAppendingString:@".app"];
	  executablePath = [executablePath stringByAppendingPathComponent:[project projectName]];
	}
      else if ([prjType isEqualToString: @"Tool"])
	{
	  /* obj/MyTool */
          executablePath = [executablePath stringByAppendingPathComponent:@"obj"];
          executablePath = [executablePath stringByAppendingPathComponent:[project projectName]];
	}
      else
	{
	  NSLog(@"Unknown project type to execute: %@", prjType);
	}
    }
  else 
    {
      NSRunAlertPanel(@"Run",
		      @"The project is not executable",
		      @"Close", nil, nil, nil);
      [runButton setState:NSOffState];
      return;
    }
  NSLog(@"executable launch path: %@", executablePath);
  // [makeTask isRunning] doesn't work here.
  // "waitpid 7045, result -1, error No child processes" is printed.
  if (launchTask)
    {
      PCLogStatus(self, @"task will terminate");
      [launchTask terminate];
      return;
    }

  // Setting I/O
  logPipe = [NSPipe pipe];
  RELEASE(readHandle);
  readHandle = [[logPipe fileHandleForReading] retain];
  [stdOut setString:@""];
  [readHandle waitForDataInBackgroundAndNotify];

  [NOTIFICATION_CENTER addObserver:self 
                          selector:@selector(logStdOut:) 
                              name:NSFileHandleDataAvailableNotification
                            object:readHandle];

  errorPipe = [NSPipe pipe];
  RELEASE(errorReadHandle);
  errorReadHandle = [[errorPipe fileHandleForReading] retain];
  [stdOut setString:@""];
  [errorReadHandle waitForDataInBackgroundAndNotify];

  [NOTIFICATION_CENTER addObserver:self 
                          selector:@selector(logErrOut:) 
                              name:NSFileHandleDataAvailableNotification
                            object:errorReadHandle];

  // Launch task
  RELEASE(launchTask);
  launchTask = [[NSTask alloc] init];

  [NOTIFICATION_CENTER addObserver:self
                          selector:@selector(runDidTerminate:)
                              name:NSTaskDidTerminateNotification
                            object:launchTask];  
  [launchTask setArguments:args];  
  [launchTask setCurrentDirectoryPath:[project projectPath]];
  [launchTask setLaunchPath:executablePath];
  [launchTask setStandardOutput:logPipe];
  [launchTask setStandardError:errorPipe];
  [launchTask launch];

  [debugButton setEnabled:NO];

  _isRunning = YES;
  RELEASE(args);
}

- (void)runDidTerminate:(NSNotification *)aNotif
{
  if ([aNotif object] != launchTask)
    {
      return;
    }

  [NOTIFICATION_CENTER removeObserver:self];

  [runButton setState:NSOffState];
  [debugButton setState:NSOffState];
  [runButton setEnabled:YES];
  [debugButton setEnabled:YES];
  [componentView display];

  RELEASE(launchTask);
  launchTask = nil;
  _isRunning = NO;
  _isDebugging = NO;

}

- (void)logStdOut:(NSNotification *)aNotif
{
  NSData *data;

  if ((data = [readHandle availableData]))
    {
      [self logData:data error:NO];
    }

  [readHandle waitForDataInBackgroundAndNotifyForModes:nil];
}

- (void)logErrOut:(NSNotification *)aNotif
{
  NSData *data;
   
  if ((data = [errorReadHandle availableData]))
    {
      [self logData:data error:YES];
    }
                       
  [errorReadHandle waitForDataInBackgroundAndNotifyForModes:nil];
}

@end

@implementation PCProjectLauncher (BuildLogging)

- (void)logString:(NSString *)str newLine:(BOOL)newLine
{
  [stdOut replaceCharactersInRange:NSMakeRange([[stdOut string] length],0) 
       withString:str];

  if (newLine) {
    [stdOut replaceCharactersInRange:NSMakeRange([[stdOut string] length], 0) 
	 withString:@"\n"];
  }
  else {
    [stdOut replaceCharactersInRange:NSMakeRange([[stdOut string] length], 0) 
	 withString:@" "];
  }
  
  [stdOut scrollRangeToVisible:NSMakeRange([[stdOut string] length], 0)];
}

- (void)logData:(NSData *)data error:(BOOL)yn
{
  NSString *s = nil;
  NSAttributedString *as = nil;

//  [self logString:s newLine:NO];
  s = [[NSString alloc] initWithData:data
                            encoding:[NSString defaultCStringEncoding]];
  as = [[NSAttributedString alloc] initWithString:s
                                       attributes:textAttributes];
  [[stdOut textStorage] appendAttributedString: as];
  [stdOut scrollRangeToVisible:NSMakeRange([[stdOut string] length], 0)];

  [s release];
  [as release];
}

@end

