/*
   GNUstep ProjectCenter - http://www.gnustep.org/experience/ProjectCenter.html

   Copyright (C) 2002-2004 Free Software Foundation

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

#import <ProjectCenter/PCDefines.h>
#import <ProjectCenter/PCFileManager.h>
#import <ProjectCenter/PCProjectManager.h>
#import <ProjectCenter/PCBundleManager.h>
#import <ProjectCenter/PCEditorManager.h>

#import <ProjectCenter/PCLogController.h>

NSString *PCEditorDidChangeFileNameNotification = 
          @"PCEditorDidChangeFileNameNotification";

NSString *PCEditorWillOpenNotification = @"PCEditorWillOpenNotification";
NSString *PCEditorDidOpenNotification = @"PCEditorDidOpenNotification";
NSString *PCEditorWillCloseNotification = @"PCEditorWillCloseNotification";
NSString *PCEditorDidCloseNotification = @"PCEditorDidCloseNotification";

NSString *PCEditorWillChangeNotification = @"PCEditorWillChangeNotification";
NSString *PCEditorDidChangeNotification = @"PCEditorDidChangeNotification";
NSString *PCEditorWillSaveNotification = @"PCEditorWillSaveNotification";
NSString *PCEditorDidSaveNotification = @"PCEditorDidSaveNotification";
NSString *PCEditorWillRevertNotification = @"PCEditorWillRevertNotification";
NSString *PCEditorDidRevertNotification = @"PCEditorDidRevertNotification";

NSString *PCEditorDidBecomeActiveNotification = 
          @"PCEditorDidBecomeActiveNotification";
NSString *PCEditorDidResignActiveNotification = 
          @"PCEditorDidResignActiveNotification";

@implementation PCEditorManager
// ===========================================================================
// ==== Initialisation
// ===========================================================================

- (id)init
{
  if ((self = [super init]))
    {
      PCLogStatus(self, @"[init]");
      _editorsDict = [[NSMutableDictionary alloc] init];

      [[NSNotificationCenter defaultCenter]
	addObserver:self 
	   selector:@selector(editorDidOpen:)
	       name:PCEditorDidOpenNotification
	     object:nil];

      [[NSNotificationCenter defaultCenter]
	addObserver:self 
	   selector:@selector(editorDidClose:)
	       name:PCEditorDidCloseNotification
	     object:nil];
	     
      [[NSNotificationCenter defaultCenter]
	addObserver:self 
	   selector:@selector(editorDidBecomeActive:)
	       name:PCEditorDidBecomeActiveNotification
	     object:nil];
	     
      [[NSNotificationCenter defaultCenter]
	addObserver:self 
	   selector:@selector(editorDidResignActive:)
	       name:PCEditorDidResignActiveNotification
	     object:nil];

      [[NSNotificationCenter defaultCenter]
	addObserver:self 
	   selector:@selector(editorDidChangeFileName:)
	       name:PCEditorDidChangeFileNameNotification
	     object:nil];
    }

  return self;
}

- (void)dealloc
{
#ifdef DEVELOPMENT
#endif
  NSLog (@"PCEditorManager: dealloc");

  [[NSNotificationCenter defaultCenter] removeObserver:self];

  RELEASE(_editorsDict);

  [super dealloc];
}

- (PCProjectManager *)projectManager
{
  return _projectManager;
}

- (void)setProjectManager:(PCProjectManager *)aProjectManager
{
  _projectManager = aProjectManager;
}

// ===========================================================================
// ==== Project and Editor handling
// ===========================================================================

- (id<CodeEditor>)editorForFile:(NSString *)filePath
{
  return [_editorsDict objectForKey:filePath];
}

- (id<CodeEditor>)openEditorForFile:(NSString *)filePath
			   editable:(BOOL)editable
			   windowed:(BOOL)windowed
{
  NSFileManager   *fm = [NSFileManager defaultManager];
  BOOL            isDir;
  PCBundleManager *bundleManager = [_projectManager bundleManager];
  NSUserDefaults  *ud = [NSUserDefaults standardUserDefaults];
  NSString        *ed = [ud objectForKey:Editor];
  NSString        *fileName = [filePath lastPathComponent];
  id<CodeEditor>  editor;
  id<CodeParser>  parser;

  NSLog(@"EditorManager: openEditorForFile: \"%@\"", filePath);

  // Determine if file not exist or file is directory
  if (![fm fileExistsAtPath:filePath isDirectory:&isDir] || isDir)
    {
      NSLog(@"%@ doesn't exist!", filePath);
      return nil;
    }

  // Determine if file is text file
  if (![[PCFileManager defaultManager] isTextFile:filePath])
    {
      NSLog(@"%@ is not plan text file!", filePath);
      return nil;
    }

  if (!(editor = [_editorsDict objectForKey:filePath]))
    {
      NSLog(@"Opening new editor");
      // Editor
      editor = [bundleManager objectForBundleWithName:ed
						 type:@"editor"
					     protocol:@protocol(CodeEditor)];
      if (editor == nil)
	{
	  editor = [bundleManager 
	    objectForBundleWithName:@"ProjectCenter"
			       type:@"editor"
			   protocol:@protocol(CodeEditor)];
	  return nil;
	}

      // Parser
      parser = [bundleManager objectForBundleType:@"parser"
					 protocol:@protocol(CodeParser)
					 fileName:fileName];
      [editor setParser:parser];
      [editor openFileAtPath:filePath 
	       editorManager:self 
		    editable:editable];

      [_editorsDict setObject:editor forKey:filePath];
      RELEASE(editor);
    }

  [editor setWindowed:windowed];

  [self orderFrontEditorForFile:filePath];

  NSLog(@"EditorManager: %@", _editorsDict);

  return editor;
}

- (void)orderFrontEditorForFile:(NSString *)path
{
  id<CodeEditor> editor = [_editorsDict objectForKey:path];

  if (!editor)
    {
      return;
    }
  [editor show];
}

- (id<CodeEditor>)activeEditor
{
  return _activeEditor;
}

- (void)setActiveEditor:(id<CodeEditor>)anEditor
{
  if (anEditor != _activeEditor)
    {
      _activeEditor = anEditor;
    }
}

- (NSArray *)allEditors
{
  return [_editorsDict allValues];
}

- (void)closeActiveEditor:(id)sender
{
  if (!_activeEditor)
    {
      return;
    }

  [_activeEditor closeFile:self save:YES];
}

- (void)closeEditorForFile:(NSString *)file
{
  id<CodeEditor> editor;

  if ([_editorsDict count] > 0 && (editor = [_editorsDict objectForKey:file]))
    {
      [editor closeFile:self save:YES];
      [_editorsDict removeObjectForKey:file];
    }
}

// ===========================================================================
// ==== Active editor file handling
// ===========================================================================

- (BOOL)saveFile
{
  id<CodeEditor> editor = [self activeEditor];

  if (editor != nil)
    {
      return [editor saveFileIfNeeded];
    }

  return NO;
}

- (BOOL)saveFileAs:(NSString *)file
{
  id<CodeEditor> editor = [self activeEditor];

  if (editor != nil)
    {
      BOOL res;
      BOOL iw = [editor isWindowed];
      
      res = [editor saveFileTo:file];
      [editor closeFile:self save:NO];

      [self openEditorForFile:file 
		     editable:YES
		     windowed:iw];

      return res;
    }

  return NO;
}

- (BOOL)saveFileTo:(NSString *)file
{
  id<CodeEditor> editor = [self activeEditor];

  if (editor != nil)
    {
      return [editor saveFileTo:file];
    }

  return NO;
}

- (BOOL)revertFileToSaved
{
  id<CodeEditor> editor = [self activeEditor];

  if (editor != nil)
    {
      return [editor revertFileToSaved];
    }

  return NO;
}

// ===========================================================================
// ==== Notifications
// ===========================================================================

- (void)editorDidOpen:(NSNotification *)aNotif
{
  id editor = [aNotif object];

  [self setActiveEditor:editor];
}

- (void)editorDidClose:(NSNotification *)aNotif
{
  id editor = [aNotif object];

  // It is not our editor
  if (![[_editorsDict allValues] containsObject:editor])
    {
      return;
    }
  
  [_editorsDict removeObjectForKey:[editor path]];

  if (![_editorsDict count])
    {
      [self setActiveEditor:nil];
    }
}

- (void)editorDidBecomeActive:(NSNotification *)aNotif
{
  id<CodeEditor> editor = [aNotif object];

  if (![[_editorsDict allValues] containsObject:editor])
    {
      return;
    }

  [self setActiveEditor:editor];
}

- (void)editorDidResignActive:(NSNotification *)aNotif
{
  // Clearing activeEditor blocks the ability to get some information from
  // loaded and visible but not active editor
/*  PCEditor *editor = [aNotif object];
  
  if ([editor projectEditor] != self)
    {
      return;
    }

  [self setActiveEditor:nil];*/
}

- (void)editorDidChangeFileName:(NSNotification *)aNotif
{
  NSDictionary   *_editorDict = [aNotif object];
  id<CodeEditor> _editor = [_editorDict objectForKey:@"Editor"];
  NSString       *_oldFileName = nil;
  NSString       *_newFileName = nil;

  if (![[_editorsDict allValues] containsObject:_editor])
    {
      return;
    }
    
  _oldFileName = [_editorDict objectForKey:@"OldFile"];
  _newFileName = [_editorDict objectForKey:@"NewFile"];
  
  [_editorsDict removeObjectForKey:_oldFileName];
  [_editorsDict setObject:_editor forKey:_newFileName];
}

@end

