/*
   GNUstep ProjectCenter - http://www.gnustep.org

   Copyright (C) 2000-2002 Free Software Foundation

   Author: Philippe C.D. Robert <probert@siggraph.org>

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

   $Id$
*/

#ifndef _SERVER_PROTO_H
#define _SERVER_PROTO_H

#include <AppKit/AppKit.h>

@class PCProject;

#ifndef GNUSTEP_BASE_VERSION
@protocol PreferenceController;
@protocol ProjectEditor;
@protocol ProjectDebugger;
#else
#include <ProjectCenter/PreferenceController.h>
#include <ProjectCenter/ProjectEditor.h>
#include <ProjectCenter/ProjectDebugger.h>
#endif

@protocol Server

- (BOOL)registerProjectSubmenu:(NSMenu *)menu;
- (BOOL)registerFileSubmenu:(NSMenu *)menu;
- (BOOL)registerToolsSubmenu:(NSMenu *)menu;
- (BOOL)registerPrefController:(id<PreferenceController>)prefs;
- (BOOL)registerEditor:(id<ProjectEditor>)anEditor;
- (BOOL)registerDebugger:(id<ProjectDebugger>)aDebugger;

- (PCProject *)activeProject;
- (NSString*)pathToActiveProject;

- (id)activeFile;
- (NSString*)pathToActiveFile;

- (NSArray*)selectedFiles;
- (NSArray*)touchedFiles;
// Returns array of paths of files that are "unsaved" or nil if none.

- (BOOL)queryTouchedFiles;
     // Prompts user to save all files and projects with dirtied buffers.

- (BOOL)addFileAt:(NSString*)filePath toProject:(PCProject *)projectPath;
- (BOOL)removeFileFromProject:(PCProject *)filePath;

@end

#endif
