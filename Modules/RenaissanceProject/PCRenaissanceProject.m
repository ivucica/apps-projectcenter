/*
   GNUstep ProjectCenter - http://www.gnustep.org

   Copyright (C) 2003 Free Software Foundation

   Authors: Philippe C.D. Robert <probert@siggraph.org>
   Modified by Daniel Luederwald <das_flip@gmx.de>

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

#include "PCRenaissanceProject.h"
#include "PCRenaissanceProj.h"

#include <ProjectCenter/PCMakefileFactory.h>

@interface PCRenaissanceProject (CreateUI)

- (void)_initUI;

@end

@implementation PCRenaissanceProject (CreateUI)

- (void)_initUI
{
  NSTextField *textField;
  NSRect       frame = {{84,120}, {80, 80}};
  NSBox       *_iconViewBox;
  NSBox       *_appIconBox;

  textField =[[NSTextField alloc] initWithFrame:NSMakeRect(16,256,64,21)];
  [textField setAlignment: NSRightTextAlignment];
  [textField setBordered: NO];
  [textField setEditable: NO];
  [textField setBezeled: NO];
  [textField setDrawsBackground: NO];
  [textField setStringValue:@"App class:"];
  [projectProjectInspectorView addSubview:textField];
  RELEASE(textField);

  appClassField =[[NSTextField alloc] initWithFrame:NSMakeRect(111,248,165,21)];
  [appClassField setAlignment: NSLeftTextAlignment];
  [appClassField setBordered: YES];
  [appClassField setEditable: YES];
  [appClassField setBezeled: YES];
  [appClassField setDrawsBackground: YES];
  [appClassField setStringValue:@""];
  [appClassField setTarget:self];
  [appClassField setAction:@selector(setAppClass:)];
  [projectProjectInspectorView addSubview:appClassField];

  // Application Icon
  _appIconBox = [[NSBox alloc] init];
  [_appIconBox setFrame:NSMakeRect(6,154,270,84)];
  [_appIconBox setContentViewMargins:NSMakeSize(4.0, 6.0)];
  [_appIconBox setTitle:@"Application Icon"];
  [projectProjectInspectorView addSubview:_appIconBox];
  RELEASE(_appIconBox);

  appImageField = [[NSTextField alloc] initWithFrame:NSMakeRect(0,34,195,21)];
  [appImageField setAlignment: NSLeftTextAlignment];
  [appImageField setBordered: YES];
  [appImageField setEditable: YES];
  [appImageField setBezeled: YES];
  [appImageField setDrawsBackground: YES];
  [appImageField setStringValue:@""];
  [_appIconBox addSubview:appImageField];
  RELEASE(appImageField);

  setAppIconButton = [[NSButton alloc] initWithFrame:NSMakeRect(147,0,48,21)];
  [setAppIconButton setTitle:@"Set..."];
  [setAppIconButton setTarget:self];
  [setAppIconButton setAction:@selector(setAppIcon:)];
  [_appIconBox addSubview:setAppIconButton];
  RELEASE(setAppIconButton);

  clearAppIconButton = [[NSButton alloc] initWithFrame:NSMakeRect(95,0,48,21)];
  [clearAppIconButton setTitle:@"Clear"];
  [clearAppIconButton setTarget:self];
  [clearAppIconButton setAction:@selector(clearAppIcon:)];
  [_appIconBox addSubview:clearAppIconButton];
  RELEASE(clearAppIconButton);

  frame = NSMakeRect(200,0,56,56);
  _iconViewBox = [[NSBox alloc] init];
  [_iconViewBox setFrame:frame];
  [_iconViewBox setTitlePosition:NSNoTitle];
  [_iconViewBox setBorderType:NSBezelBorder];
  [_appIconBox addSubview:_iconViewBox];
  RELEASE(_iconViewBox);

  appIconView = [[NSImageView alloc] initWithFrame:frame];
  [_iconViewBox addSubview:appIconView];
  RELEASE(appIconView);
}

@end

@implementation PCRenaissanceProject

//----------------------------------------------------------------------------
// Init and free
//----------------------------------------------------------------------------

- (id)init
{
  if ((self = [super init]))
    {
      rootKeys = [[NSArray arrayWithObjects: PCClasses,
						PCHeaders,
						PCOtherSources,
						PCInterfaces,
						PCImages,
						PCOtherResources,
						PCSubprojects,
						PCDocuFiles,
						PCSupportingFiles,
						PCLibraries,
						PCNonProject,
						nil] retain];

      rootCategories = [[NSArray arrayWithObjects: @"Classes",
					     @"Headers",
					     @"Other Sources",
					     @"Interfaces",
					     @"Images",
					     @"Other Resources",
					     @"Subprojects",
					     @"Documentation",
					     @"Supporting Files",
					     @"Libraries",
					     @"Non Project Files",
					     nil] retain];

      rootEntries = [[NSDictionary 
	dictionaryWithObjects:rootCategories forKeys:rootKeys] retain];
    }

  return self;
}

- (void)dealloc
{
  RELEASE(rootCategories);
  RELEASE(rootKeys);
  RELEASE(rootEntries);

  RELEASE(appClassField);
  RELEASE(appImageField);

  [super dealloc];
}

//----------------------------------------------------------------------------
// Project
//----------------------------------------------------------------------------

- (Class)builderClass
{
    return [PCRenaissanceProj class];
}

- (BOOL)writeMakefile
{
    NSData   *mfd;
    NSString *mfl = [projectPath stringByAppendingPathComponent:@"GNUmakefile"];
    int i; 
    PCMakefileFactory *mf = [PCMakefileFactory sharedFactory];
    NSDictionary      *dict = [self projectDict];

    // Save the project file
    [super writeMakefile];
   
    // Create the new file
    [mf createMakefileForProject:[self projectName]];

    [mf appendString:@"include $(GNUSTEP_MAKEFILES)/common.make\n"];
    
    [mf appendSubprojects:[dict objectForKey:PCSubprojects]];

//    [mf appendApplication];
//    [mf appendInstallDir:[dict objectForKey:PCInstallDir]];
//    [mf appendAppIcon:[dict objectForKey:PCAppIcon]];

//    [mf appendGuiLibraries:[dict objectForKey:PCLibraries]];
    [mf appendResources];
    for (i=0;i<[[self resourceFileKeys] count];i++)
    {
        NSString *k = [[self resourceFileKeys] objectAtIndex:i];
        [mf appendResourceItems:[dict objectForKey:k]];
    }

    [mf appendHeaders:[dict objectForKey:PCHeaders]];
    [mf appendClasses:[dict objectForKey:PCClasses]];
    [mf appendOtherSources:[dict objectForKey:PCOtherSources]];

//    [mf appendTailForApp];

    // Write the new file to disc!
    if ((mfd = [mf encodedMakefile]))
    {
        if ([mfd writeToFile:mfl atomically:YES]) 
        {
            return YES;
        }
    }

    return NO;
}

- (NSArray *)sourceFileKeys
{
    return [NSArray arrayWithObjects:PCClasses,PCOtherSources,nil];
}

- (NSArray *)resourceFileKeys
{
  return [NSArray arrayWithObjects:PCInterfaces,PCOtherResources,PCImages,nil];
}

- (NSArray *)otherKeys
{
    return [NSArray arrayWithObjects:PCDocuFiles,PCSupportingFiles,nil];
}

- (NSArray *)buildTargets
{
    return nil;
}

- (NSString *)projectDescription
{
    return @"Project that handles GNUstep/ObjC based applications.";
}

- (BOOL)isExecutable
{
  return YES;
}

- (void)updateValuesFromProjectDict
{
  NSRect frame = {{0,0}, {64, 64}};
  NSImage *image;
  NSString *path = nil;
  NSString *_icon;

  [super updateValuesFromProjectDict];

  [appClassField setStringValue:[projectDict objectForKey:PCPrincipalClass]];
  [appImageField setStringValue:[projectDict objectForKey:PCAppIcon]];

  if ((_icon = [projectDict objectForKey:PCAppIcon])) {
    path = [projectPath stringByAppendingPathComponent:_icon];
  }

  if (path && (image = [[NSImage alloc] initWithContentsOfFile:path])) {
    frame.size = [image size];
    [appIconView setFrame:frame];
    [appIconView setImage:image];
    [appIconView display];
    RELEASE(image);
  }
}

- (void)clearAppIcon:(id)sender
{
  [projectDict setObject:@"" forKey:PCAppIcon];
  [appImageField setStringValue:@"No Icon!"];
  [appIconView setImage:nil];
  [appIconView display];

  [[NSNotificationCenter defaultCenter] 
    postNotificationName:PCProjectDictDidChangeNotification
                  object:self];
}

- (void)setAppIcon:(id)sender
{
  int result;  
  NSArray *fileTypes = [NSImage imageFileTypes];
  NSOpenPanel *openPanel = [NSOpenPanel openPanel];

  [openPanel setAllowsMultipleSelection:NO];
  result = [openPanel runModalForDirectory:NSHomeDirectory()
		      file:nil 
		      types:fileTypes];
  
  if (result == NSOKButton) {
    NSArray *files = [openPanel filenames];
    NSString *imageFilePath = [files objectAtIndex:0];      

    if (![self setAppIconWithImageAtPath:imageFilePath]) {
      NSRunAlertPanel(@"Error while opening file!", 
		      @"Couldn't open %@", @"OK", nil, nil,imageFilePath);
    }
  }  
}

- (BOOL)setAppIconWithImageAtPath:(NSString *)path
{
  NSRect frame = {{0,0}, {64, 64}};
  NSImage *image;

  if (!(image = [[NSImage alloc] initWithContentsOfFile:path])) {
    return NO;
  }

  [self addFiles:[NSArray arrayWithObject:path] forKey:PCImages];
  [projectDict setObject:[path lastPathComponent] forKey:PCAppIcon];

  [appImageField setStringValue:[path lastPathComponent]];

  frame.size = [image size];
  [appIconView setFrame:frame];
  [appIconView setImage:image];
  [appIconView display];
  RELEASE(image);

  [[NSNotificationCenter defaultCenter] 
    postNotificationName:PCProjectDictDidChangeNotification
                  object:self];

  return YES;
}

- (void)setAppClass:(id)sender
{
  [projectDict setObject:[appClassField stringValue] forKey:PCPrincipalClass];
  [[NSNotificationCenter defaultCenter] 
    postNotificationName:PCProjectDictDidChangeNotification
                  object:self];
}

@end