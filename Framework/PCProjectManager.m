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

#include <ProjectCenter/PCDefines.h>
#include <ProjectCenter/PCPrefController.h>
#include <ProjectCenter/PCLogController.h>

#include <ProjectCenter/PCBundleManager.h>
#include <ProjectCenter/PCFileManager.h>
#include <ProjectCenter/PCProjectManager.h>

#include <ProjectCenter/PCProject.h>
#include <ProjectCenter/PCProjectWindow.h>
#include <ProjectCenter/PCProjectBrowser.h>
#include <ProjectCenter/PCProjectInspector.h>
#include <ProjectCenter/PCProjectEditor.h>
#include <ProjectCenter/PCProjectBuilderPanel.h>
#include <ProjectCenter/PCProjectLauncherPanel.h>
#include <ProjectCenter/PCProjectLoadedFilesPanel.h>

#include "Protocols/ProjectType.h"
#include "Protocols/CodeEditor.h"

NSString *PCActiveProjectDidChangeNotification = @"PCActiveProjectDidChange";

@implementation PCProjectManager

// ============================================================================
// ==== Intialization & deallocation
// ============================================================================

- (id)init
{
  if ((self = [super init]))
    {
      buildPanel = nil;
      launchPanel = nil;
      loadedFilesPanel = nil;
      findPanel = nil;

      // Prepare bundles
      bundleManager = [[PCBundleManager alloc] init];
      projectTypes = [self loadProjectTypesInfo];
      
      loadedProjects = [[NSMutableDictionary alloc] init];
      
      nonProjectEditors = [[NSMutableDictionary alloc] init];

      [[NSNotificationCenter defaultCenter] 
	addObserver:self 
	   selector:@selector(resetSaveTimer:)
	       name:PCSavePeriodDidChangeNotification
	     object:nil];

      [[NSNotificationCenter defaultCenter] 
	addObserver:self 
	   selector:@selector(editorDidClose:)
	       name:PCEditorDidCloseNotification
	     object:nil];

      fileManager = [[PCFileManager alloc] initWithProjectManager:self];
    }

  return self;
}

- (void)dealloc
{
#ifdef DEVELOPMENT
  NSLog (@"PCProjectManager: dealloc");
#endif

  [[NSNotificationCenter defaultCenter] removeObserver:self];

  if ([saveTimer isValid])
    {
      [saveTimer invalidate];
    }

  RELEASE(loadedProjects);
  RELEASE(nonProjectEditors);
  RELEASE(fileManager);

  RELEASE(bundleManager);
  RELEASE(projectTypes);
  RELEASE(projectTypeAccessaryView);
  RELEASE(fileTypeAccessaryView);

  if (projectInspector) RELEASE(projectInspector);
  if (loadedFilesPanel) RELEASE(loadedFilesPanel);
  if (buildPanel)       RELEASE(buildPanel);
  if (launchPanel)      RELEASE(launchPanel);

  [super dealloc];
}

- (void)setDelegate:(id)aDelegate 
{
  delegate = aDelegate;
}

- (id)delegate
{
  return delegate;
}

- (void)setPrefController:(id)aController
{
  prefController = aController;
}

- (id)prefController
{
  return prefController;
}

- (void)createProjectTypeAccessaryView
{
  NSRect fr = NSMakeRect(20,30,160,20);

  if (projectTypeAccessaryView != nil)
    {
      return;
    }

  // For "Open Project" and "New Project" panels
  projectTypePopup = [[NSPopUpButton alloc] initWithFrame:fr pullsDown:NO];
  [projectTypePopup setRefusesFirstResponder:YES];
  [projectTypePopup setAutoenablesItems:NO];
  [projectTypePopup addItemsWithTitles:
    [[projectTypes allKeys] 
    sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)]];
  [projectTypePopup sizeToFit];
  [projectTypeAccessaryView sizeToFit];
  [projectTypePopup selectItemAtIndex:0];

  projectTypeAccessaryView = [[NSBox alloc] init];
  [projectTypeAccessaryView setTitle:@"Project Types"];
  [projectTypeAccessaryView setTitlePosition:NSAtTop];
  [projectTypeAccessaryView setBorderType:NSGrooveBorder];
  [projectTypeAccessaryView addSubview:projectTypePopup];
  [projectTypeAccessaryView sizeToFit];
  [projectTypeAccessaryView setAutoresizingMask:NSViewMinXMargin 
                                                | NSViewMaxXMargin];
  RELEASE(projectTypePopup);
}

- (NSMutableDictionary *)loadProjectTypesInfo
{
  NSDictionary *bundlesInfo;
  NSEnumerator *enumerator;
  NSArray      *bundlePaths;
  NSString     *key;
  NSDictionary *infoTable;
  
  if (projectTypes == nil)
    {
      projectTypes = [[NSMutableDictionary alloc] init];
      bundlesInfo = [bundleManager infoForBundlesOfType:@"project"];

      bundlePaths = [bundlesInfo allKeys];
      enumerator = [bundlePaths objectEnumerator];

      while ((key = [enumerator nextObject]))
	{
	  infoTable = [bundlesInfo objectForKey:key];
	  [projectTypes setObject:[infoTable objectForKey:@"PrincipalClassName"]
	                   forKey:[infoTable objectForKey:@"Name"]];
	}
    }

  return projectTypes;
}

// ============================================================================
// ==== Timer handling
// ============================================================================

- (BOOL)startSaveTimer
{
  NSTimeInterval interval;

  interval = [[[PCPrefController sharedPCPreferences] 
    objectForKey:AutoSavePeriod] intValue];

  if (interval > 0 && saveTimer == nil)
    {
      saveTimer = [NSTimer 
	scheduledTimerWithTimeInterval:interval
	                        target:self
	                      selector:@selector(saveAllProjects)
	                      userInfo:nil
	                       repeats:YES];
      return YES;
    }
  return NO;
}

- (BOOL)resetSaveTimer:(NSNotification *)notif
{
  [self stopSaveTimer];

  return [self startSaveTimer];
}

- (BOOL)stopSaveTimer
{
  if (saveTimer && [saveTimer isValid])
    {
      [saveTimer invalidate];
      saveTimer = nil;

      return YES;
    }
  return NO;
}

// ============================================================================
// ==== Accessory methods
// ============================================================================

- (PCBundleManager *)bundleManager
{
  return bundleManager;
}

- (PCFileManager *)fileManager
{
  return fileManager;
}

- (PCProjectInspector *)projectInspector
{
  if (!projectInspector)
    {
      projectInspector = 
	[[PCProjectInspector alloc] initWithProjectManager:self];
    }

  return projectInspector;
}

- (NSPanel *)inspectorPanel
{
  return [[self projectInspector] panel];
}

- (void)showProjectInspector:(id)sender
{
  [[[self projectInspector] panel] makeKeyAndOrderFront:self];
}

- (NSPanel *)loadedFilesPanel
{
  NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];

  if (!loadedFilesPanel
      && [[ud objectForKey:SeparateLoadedFiles] isEqualToString:@"YES"])
    {
      loadedFilesPanel = 
	[[PCProjectLoadedFilesPanel alloc] initWithProjectManager:self];
    }

  return loadedFilesPanel;
}

- (void)showProjectLoadedFiles:(id)sender
{
  if ([[[[NSUserDefaults standardUserDefaults] dictionaryRepresentation]
              objectForKey: SeparateLoadedFiles] isEqualToString: @"YES"])
    {
      [[self loadedFilesPanel] orderFront: nil];
    }
}

- (NSPanel *)buildPanel
{
  NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];

  if (!buildPanel
      && [[ud objectForKey:SeparateBuilder] isEqualToString:@"YES"])
    {
      buildPanel = [[PCProjectBuilderPanel alloc] initWithProjectManager:self];
    }

  return buildPanel;
}

- (NSPanel *)launchPanel
{
  NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];

  if (!launchPanel
      && [[ud objectForKey:SeparateLauncher] isEqualToString:@"YES"])
    {
      launchPanel = [[PCProjectLauncherPanel alloc] initWithProjectManager:self];
    }

  return launchPanel;
}

- (NSPanel *)projectFinderPanel
{
  return findPanel;
}

- (NSString *)projectPath
{
  return [activeProject projectPath];
}

- (NSString *)selectedFileName
{
  return [[activeProject projectBrowser] nameOfSelectedFile];
}

// ============================================================================
// ==== Project management
// ============================================================================

- (NSMutableDictionary *)loadedProjects
{
  return loadedProjects;
}

- (PCProject *)activeProject
{
  return activeProject;
}

- (PCProject *)rootActiveProject
{
  PCProject *rootProject = nil;

  if (!activeProject)
    {
      return nil;
    }
  
  rootProject = activeProject;
  while ([rootProject isSubproject] == YES)
    {
      rootProject = [rootProject superProject];
    }

  return rootProject;
}

- (void)setActiveProject:(PCProject *)aProject
{
  if (aProject != activeProject)
    {
      activeProject = aProject;

      [[NSNotificationCenter defaultCenter]
	postNotificationName:PCActiveProjectDidChangeNotification
	              object:activeProject];
    }
}

- (void)saveAllProjectsIfNeeded
{
  NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];

//  PCLogInfo(self, @"saveAllProjectsIfNeeded");

  // If this method was called not by NSTimer, check if we should save projects
  if ([[defs objectForKey:SaveOnQuit] isEqualToString:@"YES"])
    {
      [self saveAllProjects];
    }
}

- (BOOL)saveAllProjects
{
  NSEnumerator *enumerator = [loadedProjects keyEnumerator];
  NSString     *key;
  PCProject    *project;

  while ((key = [enumerator nextObject]))
    {
      project = [loadedProjects objectForKey:key];

      if ([project save] == NO)
	{
	  return NO;
	}
    }

  return YES;
}

// ============================================================================
// ==== Project actions
// ============================================================================

- (PCProject *)convertLegacyProject:(NSMutableDictionary *)pDict
                             atPath:(NSString *)aPath
{
  NSString               *pPath = nil;
  NSString               *projectClassName = nil;
  NSString               *projectTypeName = nil;
  NSString               *_projectPath = nil;
  NSFileManager          *fm = [NSFileManager defaultManager];
  NSString               *_resPath = nil;
  NSArray                *_fromDirArray = nil;
  NSString               *_fromDirPath = nil;
  NSString               *_file = nil;
  NSString               *_2file = nil;
  NSString               *_resFile = nil;
  unsigned               i = 0;
  PCProject<ProjectType> *project = nil;
  NSMutableArray         *otherResArray = nil;
  NSString               *plistFile = nil;

  projectClassName = [pDict objectForKey:PCProjectBuilderClass];
  if (projectClassName == nil)
    {
      // Project created by 0.4 release or later
      return nil;
    }

  NSLog(@"Convert legacy");

  // Gorm project type doesn't exists anymore
  if ([projectClassName isEqualToString:@"PCGormProj"])
    {
      projectTypeName = [NSString stringWithString:@"Application"];
      projectClassName = [projectTypes objectForKey:projectTypeName];
    }

  // Handling directory layout
  _projectPath = [aPath stringByDeletingLastPathComponent];
  _resPath = [_projectPath stringByAppendingPathComponent:@"Resources"];
  [fm createDirectoryAtPath:_resPath attributes:nil];

  // Documents
  _fromDirPath = [_projectPath stringByAppendingPathComponent:@"Documentation"];
  _fromDirArray = [pDict objectForKey:PCDocuFiles];
  for (i = 0; i < [_fromDirArray count]; i++)
    {
      _resFile = [_fromDirArray objectAtIndex:i];
      _file = [_fromDirPath stringByAppendingPathComponent:_resFile];
      _2file = [_resPath stringByAppendingPathComponent:_resFile];
      [fm movePath:_file toPath:_2file handler:nil];
    }
  [fm removeFileAtPath:_fromDirPath handler:nil];

  // Images
  _fromDirPath = [_projectPath stringByAppendingPathComponent:@"Images"];
  _fromDirArray = [pDict objectForKey:PCImages];
  for (i = 0; i < [_fromDirArray count]; i++)
    {
      _resFile = [_fromDirArray objectAtIndex:i];
      _file = [_fromDirPath stringByAppendingPathComponent:_resFile];
      _2file = [_resPath stringByAppendingPathComponent:_resFile];
      [fm movePath:_file toPath:_2file handler:nil];
    }
  [fm removeFileAtPath:_fromDirPath handler:nil];
  
  // Interfaces
  _fromDirArray = [pDict objectForKey:PCInterfaces];
  for (i = 0; i < [_fromDirArray count]; i++)
    {
      _resFile = [_fromDirArray objectAtIndex:i];
      _file = [_projectPath stringByAppendingPathComponent:_resFile];
      _2file = [_resPath stringByAppendingPathComponent:_resFile];
      [fm movePath:_file toPath:_2file handler:nil];
    }

  // Other resources
  otherResArray = [NSMutableArray 
    arrayWithArray:[pDict objectForKey:PCOtherResources]];
  plistFile = [NSString stringWithFormat:@"%@Info.plist",
               [pDict objectForKey:PCProjectName]];
  for (i = 0; i < [otherResArray count]; i++)
    {
      _resFile = [otherResArray objectAtIndex:i];
      _file = [_projectPath stringByAppendingPathComponent:_resFile];
      if ([_resFile isEqualToString:plistFile])
	{
	  _2file = 
	    [_resPath stringByAppendingPathComponent:@"Info-gnustep.plist"];
	  [otherResArray replaceObjectAtIndex:i 
	                           withObject:@"Info-gnustep.plist"];
	  [pDict setObject:otherResArray forKey:PCOtherResources];
	}
      else
	{
	  _2file = [_resPath stringByAppendingPathComponent:_resFile];
	}
      [fm movePath:_file toPath:_2file handler:nil];
    }

  // GNUmakefiles will be generated in [PCProject initWithProjectDictionary:]

  // Remove obsolete records from project dictionary and write to PC.project
  pPath = [[aPath stringByDeletingLastPathComponent]
    stringByAppendingPathComponent:@"PC.project"];

  project = [bundleManager objectForClassName:projectClassName
                                 withProtocol:@protocol(ProjectType)
				 inBundleType:@"project"];

  projectTypeName = [project projectTypeName];
  [pDict setObject:projectTypeName forKey:PCProjectType];
  [pDict removeObjectForKey:PCProjectBuilderClass];
  [pDict removeObjectForKey:PCPrincipalClass];

  if ([pDict writeToFile:pPath atomically:YES] == YES)
    {
//      [[NSFileManager defaultManager] removeFileAtPath:aPath handler:nil];
    }

  return project;
}

- (PCProject *)loadProjectAt:(NSString *)aPath
{
  NSMutableDictionary    *projectFile = nil;
  NSString               *projectTypeName = nil;
  NSString               *projectClassName = nil;
  PCProject<ProjectType> *project = nil;

  projectFile = [NSMutableDictionary dictionaryWithContentsOfFile:aPath];
  
  // For compatibility with 0.3.x projects
  project = [self convertLegacyProject:projectFile atPath:aPath];
  if (project)
    {// Project was converted and created PC*Project with alloc&init
      aPath = [[aPath stringByDeletingLastPathComponent]
	stringByAppendingPathComponent:@"PC.project"];
    }
  else
    {// No conversion were taken
      projectTypeName = [projectFile objectForKey:PCProjectType];
      projectClassName = [projectTypes objectForKey:projectTypeName];
      if (projectClassName == nil)
	{
	  NSRunAlertPanel(@"Load Project",
			  @"Project type '%@' is not supported!",
			  @"OK",nil,nil,projectTypeName); 
	  return nil;
	}
      project = [bundleManager objectForClassName:projectClassName
                                     withProtocol:@protocol(ProjectType)
				     inBundleType:@"project"];
    }

  if (![project openWithDictionaryAt:aPath]) 
    {
      NSRunAlertPanel(@"Load Project",
    		      @"Could not load project '%@'!",
    		      @"OK",nil,nil,aPath); 
      return nil;
    }

  PCLogStatus(self, @"Project %@ loaded as %@", 
	      [project projectName], [project projectTypeName]);

  // Started only if there's not save timer yet
  [self startSaveTimer];
  [project validateProjectDict];

  return project;
}

- (BOOL)openProjectAt:(NSString *)aPath
{
  NSDictionary *pDict = [NSDictionary dictionaryWithContentsOfFile:aPath];
  NSString     *projectName = nil;
  PCProject    *project = nil;
  NSDictionary *wap = nil;
  BOOL         isDir = NO;

  projectName = [pDict objectForKey:PCProjectName];

  if ((project = [loadedProjects objectForKey:projectName]) != nil)
    {
      [[project projectWindow] makeKeyAndOrderFront:self];
      return YES;
    }

  if ([[NSFileManager defaultManager] fileExistsAtPath:aPath 
                                           isDirectory:&isDir] && !isDir) 
    {
      project = [self loadProjectAt:aPath];

      if (!project) 
	{
	  return NO;
	}

      [loadedProjects setObject:project forKey:projectName];
      [self setActiveProject:project];
      [project setProjectManager:self];

      // Windows and panels
      wap = [pDict objectForKey:@"PC_WINDOWS"];
      if ([[wap allKeys] containsObject:@"ProjectBuild"])
	{
	  [[project projectWindow] showProjectBuild:self];
	}
      if ([[wap allKeys] containsObject:@"ProjectLaunch"])
	{
	  [[project projectWindow] showProjectLaunch:self];
	}
      if ([[wap allKeys] containsObject:@"LoadedFiles"])
	{
	  [[project projectWindow] showProjectLoadedFiles:self];
	}
      return YES;
    }

  return NO;
}

- (PCProject *)createProjectOfType:(NSString *)projectType 
                              path:(NSString *)aPath
{
  NSString               *className = [projectTypes objectForKey:projectType];
  PCProject<ProjectType> *projectCreator;
  PCProject              *project = nil;
  NSString               *projectName = [aPath lastPathComponent];

  if ((project = [loadedProjects objectForKey:projectName]) != nil)
    {
      [[project projectWindow] makeKeyAndOrderFront:self];
      return project;
    }

  projectCreator = [bundleManager objectForClassName:className 
                                        withProtocol:@protocol(ProjectType)
					inBundleType:@"project"];
//  NSLog(@"%@ CLASS: %@", className, projectCreator);
  if (!projectCreator)
    {
      return nil;
    }

  // Create project directory
  if (![[PCFileManager defaultManager] createDirectoriesIfNeededAtPath:aPath])
    {
      return nil;
    }

  // Create project
  if (!(project = [projectCreator createProjectAt:aPath])) 
    {
      return nil;
    }

  [project setProjectManager:self];
  [self startSaveTimer];

  return project;
}

- (void)openProject
{
  NSArray  *files = nil;
  NSString *filePath = nil;
  NSArray  *fileTypes = [NSArray arrayWithObjects:@"project",@"pcproj",nil];

  files = [fileManager filesForOpenOfType:fileTypes
                                 multiple:NO
			            title:@"Open Project"
				  accView:nil];
  filePath = [files objectAtIndex:0];

  if (filePath != nil)
    {
      [self openProjectAt:filePath];
      [[activeProject projectWindow] makeKeyAndOrderFront:self];

/*      NSRunAlertPanel(@"Attention!",
		      @"Couldn't open project %@!",
		      @"OK",nil,nil,
		      [filePath stringByDeletingLastPathComponent]);*/
    }
}

- (void)newProject
{
  NSString  *filePath = nil;
  NSArray   *fileTypes = [NSArray arrayWithObjects:@"project",@"pcproj",nil];
  NSString  *projectType = nil;
  PCProject *project = nil;

  [self createProjectTypeAccessaryView];
  
  filePath = [fileManager fileForSaveOfType:fileTypes
	  		              title:@"New Project"
				    accView:projectTypeAccessaryView];
  if (filePath != nil) 
    {
      projectType = [projectTypePopup titleOfSelectedItem];

      if (!(project = [self createProjectOfType:projectType path:filePath]))
	{
	  NSRunAlertPanel(@"Attention!",
			  @"Failed to create %@!",
			  @"OK",nil,nil,filePath);
	}

      [loadedProjects setObject:project forKey:[project projectName]];
      [self setActiveProject:project];
      [[project projectWindow] orderFront:self];
    }
}

- (BOOL)saveProject
{
  PCProject *rootProject = [self rootActiveProject];

  if (!rootProject)
    {
      return NO;
    }
    
//  PCLogInfo(self, @"save root project: %@", [rootProject projectName]);

  // Save PC.project and the makefiles!
  if ([rootProject save] == NO)
    {
      NSRunAlertPanel(@"Attention!",
		      @"Couldn't save project %@!", 
		      @"OK",nil,nil,[activeProject projectName]);
      return NO;
    }

  return YES;
}

- (BOOL)addProjectFiles
{
  PCProject      *project = [self rootActiveProject];
  NSString       *category = [[project projectBrowser] nameOfSelectedCategory];
  NSString       *categoryKey = [activeProject keyForCategory:category];
  NSMutableArray *files = nil;
  NSString       *file = nil;
  NSString       *projectFile = nil;
  NSArray        *fileTypes = [project fileTypesForCategoryKey:categoryKey];

  files = [fileManager filesForAddOfTypes:fileTypes];

/*  PCLogInfo(self, @"[addProjectFiles] %@ to category: %@ of project %@",
	    files, categoryKey, [activeProject projectName]);*/

  // Category may be changed
  category = [[project projectBrowser] nameOfSelectedCategory];
  categoryKey = [activeProject keyForCategory:category];
  
  // No files was selected 
  if (!files)
    {
      return NO;
    }

  file = [[files objectAtIndex:0] lastPathComponent];
  projectFile = [activeProject projectFileFromFile:[files objectAtIndex:0] 
                                            forKey:categoryKey];

  if (![projectFile isEqualToString:file])
    {
      [activeProject addFiles:files forKey:categoryKey notify:YES];
    }
  else
    {
      // Copy and add files
      [activeProject addAndCopyFiles:files forKey:categoryKey];
    }

  return YES;
}

- (BOOL)saveProjectFiles
{
  return [[activeProject projectEditor] saveAllFiles];
}

- (BOOL)removeProjectFiles
{
  PCProject      *project = [self rootActiveProject];
  NSArray        *files = [[project projectBrowser] selectedFiles];
  NSString       *category = [[project projectBrowser] nameOfSelectedCategory];
  NSString       *categoryKey = [project keyForCategory:category];
  NSString       *directory = [activeProject dirForCategoryKey:categoryKey];
  NSString       *removeString = nil;
  NSMutableArray *subprojs = [NSMutableArray array];
  unsigned       i;

  // Determining target project
  if ([categoryKey isEqualToString:PCSubprojects])
    {
      if ([activeProject isSubproject])
	{
	  project = [activeProject superProject];
	  [self setActiveProject:project];
	}
      removeString = [NSString stringWithString:@"Remove subprojects..."];
      directory = [project dirForCategoryKey:categoryKey];
    }
  else
    {
      removeString = [NSString stringWithString:@"Remove files..."];
      project = activeProject;
    }

/*  PCLogInfo(self, @"%@: %@ from %@", removeString, files, directory);
  PCLogInfo(self, @"[removeProjectFiles]:%@ KEY:%@", 
	    [activeProject projectName], categoryKey);*/

  if (files)
    {
      int ret;

      if ([categoryKey isEqualToString:PCLibraries])
	{
	  ret = NSRunAlertPanel(@"Remove",
				@"Remove libraries from Project?",
				@"Remove",
				@"Cancel",
				nil);
	}
      else
	{
	  ret = NSRunAlertPanel(@"Remove",
				removeString,
				@"...from Project and Disk",
				@"...from Project only",
				@"Cancel");
	}

      if (ret == NSAlertDefaultReturn || ret == NSAlertAlternateReturn)
	{
	  BOOL flag = (ret == NSAlertDefaultReturn) ? YES : NO;

	  // Remove from projectDict
	  // If files localizable make them not localizable
	  ret = [project removeFiles:files forKey:categoryKey notify:YES];

	  // Remove files from disk
	  if (flag && ret && ![categoryKey isEqualToString:PCLibraries])
	    {
	      if ([categoryKey isEqualToString:PCSubprojects])
		{
		  for (i = 0; i < [files count]; i++)
		    {
		      [subprojs addObject:
			[[files objectAtIndex:i] 
			stringByAppendingPathExtension:@"subproj"]];
		    }
		  files = subprojs;
		}
    	      ret = [fileManager removeFiles:files 
		               fromDirectory:directory
			   removeDirsIfEmpty:YES];
	    }

	  if (!ret)
	    {
	      NSRunAlertPanel(@"Alert",
			      @"Error removing files from project %@!",
			      @"OK", nil, nil, [activeProject projectName]);
	      return NO;
	    }
	  else if (flag) 
	    {
	      // Save project because we've removed file(s) from disk
	      // Should be fixed later (add pending removal of files?)
	      [activeProject save];
	    }
	}
      else
	{
	  return NO;
	}
    } // files

  return YES;
}

- (void)closeProject:(PCProject *)aProject
{
  PCProject *currentProject = nil;
  NSString  *projectName = [aProject projectName];

  currentProject = [loadedProjects objectForKey:projectName];
  if (!currentProject)
    {
      return;
    }

  // Remove it from the loaded projects!
  [loadedProjects removeObjectForKey:projectName];

  if ([loadedProjects count] == 0)
    {
      if (projectInspector)
	{
	  [projectInspector close];
	}
      if (loadedFilesPanel && [loadedFilesPanel isVisible])
	{
	  [loadedFilesPanel close];
	}
      if (buildPanel && [buildPanel isVisible])
	{
	  [buildPanel close];
	}
      if (launchPanel && [launchPanel isVisible])
	{
	  [launchPanel close];
	}
      [self setActiveProject:nil];
      [self stopSaveTimer];
    }
  else if (currentProject == [self activeProject])
    {
      [self setActiveProject:[[loadedProjects allValues] lastObject]];
    }

  RELEASE(currentProject);
}

- (void)closeProject
{
  NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];

  if ([[defs objectForKey:SaveOnQuit] isEqualToString:@"YES"])
    {
      [activeProject save];
    }

  [activeProject close:self];
}

- (BOOL)closeAllProjects
{
  PCProject      *project = nil;
  NSEnumerator   *enumerator = [loadedProjects objectEnumerator];
  NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];

//  PCLogInfo(self, @"loaded %i projects", [loadedProjects count]);

  while ([loadedProjects count] > 0)
    {
      project = [enumerator nextObject];
      if ([[defs objectForKey:SaveOnQuit] isEqualToString:@"YES"])
	{
	  [project save];
	}
      if ([project close:self] == NO)
	{
	  return NO;
	}
    }
   
  return YES;
}

// ============================================================================
// ==== File actions
// ============================================================================

- (void)openFile
{
  NSArray  *files = nil;
  NSString *filePath = nil;

  files = [fileManager filesForOpenOfType:nil
                                 multiple:NO
			            title:@"Open File"
				  accView:nil];
  filePath = [files objectAtIndex:0];

  if (filePath != nil)
    {
      [self openFileWithEditor:filePath];
    }
}

- (void)newFile
{
  [fileManager showNewFilePanel];
}

- (BOOL)saveFile
{
  return [[activeProject projectEditor] saveFile];
}

- (BOOL)saveFileAs:(NSString *)path
{
  return [[activeProject projectEditor] saveFileAs:path];
}

- (BOOL)saveFileTo
{
  NSString *filePath = nil;

  filePath = [fileManager fileForSaveOfType:nil
			              title:@"Save To..."
				    accView:nil];

  if (filePath != nil && ![[activeProject projectEditor] saveFileTo:filePath]) 
    {
      NSRunAlertPanel(@"Alert", @"Couldn't save file to\n%@!",
		      @"OK", nil, nil, filePath);
      return NO;
    }

  return YES;
}

- (BOOL)revertFileToSaved
{
  return [[activeProject projectEditor] revertFileToSaved];
}

- (BOOL)renameFile
{
  [self showProjectInspector:self];
  [projectInspector selectSectionWithTitle:@"File Attributes"];
  [projectInspector beginFileRename];

  return YES;
}

- (void)closeFile
{
  return [[activeProject projectEditor] closeActiveEditor:self];
}

// Project menu
// ============================================================================
// ==== Non project editors
// ============================================================================

- (void)openFileWithEditor:(NSString *)path
{
/*  id<CodeEditor> editor;
  NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
  NSString       *editor = [ud objectForKey:Editor];

  editor = [PCProjectEditor openFileInEditor:path];

  if (![editor isEqualToString:@"ProjectCenter"])
    {
      NSArray  *ea = [editor componentsSeparatedByString:@" "];
      NSString *app = [ea objectAtIndex: 0];

      if ([[app pathExtension] isEqualToString:@"app"])
	{
	  BOOL ret = [[NSWorkspace sharedWorkspace] openFile:path 
	    withApplication:app];

	  if (ret == NO)
	    {
	      PCLogError(self, @"Could not open %@ using %@", path, app);
	    }

	  return nil;
	}

      editor = [[editorClass alloc] initExternalEditor:editor 
	withPath:path
	projectEditor:self];
    }
  else
    {
      id<CodeEditor> editor;

      editor = [[editorClass alloc] initWithPath:path 
	categoryPath:nil
	projectEditor:self];
      [editor setWindowed:YES];
      [editor show];

      return editor;
    }

  return nil;
  
  [nonProjectEditors setObject:editor forKey:path];

  [editor release];*/
}

- (void)editorDidClose:(NSNotification *)aNotif
{
  id<CodeEditor> editor = [aNotif object];
  
  [nonProjectEditors removeObjectForKey:[editor path]];
}

@end

@implementation PCProjectManager (FileManagerDelegates)

// willCreateFile
- (NSString *)fileManager:(id)sender
           willCreateFile:(NSString *)aFile
	          withKey:(NSString *)key
{
  NSString *path = nil;

  if ([activeProject doesAcceptFile:aFile forKey:key]) 
    {
      path = [[activeProject projectPath] stringByAppendingPathComponent:aFile];
    }

  return path;
}

// didCreateFiles
- (void)fileManager:(id)sender
      didCreateFile:(NSString *)aFile
            withKey:(NSString *)key
{
  [activeProject addFiles:[NSArray arrayWithObject:aFile]
                   forKey:key
		   notify:YES];
}

@end

@implementation PCProjectManager (Subprojects)

- (BOOL)newSubproject
{
//  PCLogInfo(self, @"newSubproject");

  if (!nsPanel)
    {
      if ([NSBundle loadNibNamed:@"NewSubproject" owner:self] == NO)
	{
	  PCLogError(self, @"error loading NewSubproject NIB!");
	  return NO;
	}

      [nsPanel setFrameAutosaveName:@"NewSubproject"];
      if (![nsPanel setFrameUsingName: @"NewSubproject"])
    	{
	  [nsPanel center];
	}

      [nsImage setImage:[NSApp applicationIconImage]];
      [nsTypePB removeAllItems];
      [nsTypePB addItemsWithTitles:
	[[activeProject allowableSubprojectTypes] 
	sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)]];
      [nsTypePB setRefusesFirstResponder:YES];
      [nsTypePB selectItemAtIndex:0];
      [nsCancelButton setRefusesFirstResponder:YES];
      [nsCreateButton setRefusesFirstResponder:YES];
    }
  [projectNameField setStringValue:[activeProject projectName]];
  [nsPanel makeKeyAndOrderFront:nil];
  [nsNameField setStringValue:@""];
  [nsPanel makeFirstResponder:nsNameField];

  return YES;
}

- (void)closeNewSubprojectPanel:(id)sender
{
  [nsPanel orderOut:self];
}

- (BOOL)createSubproject:(id)sender
{
  [nsPanel orderOut:self];

  return [self createSubproject];
}

- (BOOL)createSubproject
{
  PCProject *subproject = nil;
  NSString  *spName = [nsNameField stringValue];
  NSString  *spPath = nil;
  NSString  *spType = [nsTypePB titleOfSelectedItem];

  if (![[spName pathExtension] isEqualToString:@"subproj"])
    {
      spName = [[nsNameField stringValue] 
	stringByAppendingPathExtension:@"subproj"];
    }

  spPath = [[activeProject projectPath] stringByAppendingPathComponent:spName];

  PCLogStatus(self, @"creating subproject with type %@ at path %@",
	      spType, spPath);

  // Create subproject
  subproject = [self createSubprojectOfType:spType path:spPath];

  return YES;
}

- (PCProject *)createSubprojectOfType:(NSString *)projectType 
                                 path:(NSString *)aPath
{
  NSString               *className = [projectTypes objectForKey:projectType];
  PCProject<ProjectType> *projectCreator;
  PCProject              *subproject = nil;
/*  NSString  *subprojectName = [aPath lastPathComponent];

  if ((project = [activeProject objectForKey:projectName]) != nil)
    {
      [[project projectWindow] makeKeyAndOrderFront:self];
      return project;
    }*/

  projectCreator = [bundleManager objectForClassName:className 
                                        withProtocol:@protocol(ProjectType)
					inBundleType:@"project"];
  if (!(subproject = [projectCreator createProjectAt:aPath])) 
    {
      return nil;
    }
  [subproject setIsSubproject:YES];
  [subproject setSuperProject:activeProject];
  [subproject setProjectManager:self];

//  PCLogInfo(self, @"{createSubproject} add to %@", [activeProject projectName]);
  [activeProject addSubproject:subproject];

  return subproject;
}

- (void)controlTextDidChange:(NSNotification *)aNotif
{
  if ([aNotif object] != nsNameField)
    {
      return;
    }
    
  // TODO: Add check for valid subproject named
  if ([[nsNameField stringValue] length] > 0)
    {
      [nsCreateButton setEnabled:YES];
    }
  else
    {
      [nsCreateButton setEnabled:NO];
    }
}

- (BOOL)addSubproject
{
  NSFileManager  *fm = [NSFileManager defaultManager];
  NSMutableArray *files = nil;
  NSString       *pcProject = nil;
  NSString       *spDir = nil;
  NSDictionary   *spDict = nil;
  NSString       *spName = nil;
  unsigned       i;

  files = [fileManager 
    filesForAddOfTypes:[NSArray arrayWithObjects:@"subproj",nil]];

  // Validate if it real projects
  for (i = 0; i < [files count]; i++)
    {
      spDir = [files objectAtIndex:i];
      pcProject = [spDir stringByAppendingPathComponent:@"PC.project"];
      if (![[spDir pathExtension] isEqualToString:@"subproj"]
	  || ![fm fileExistsAtPath:pcProject])
	{
	  [files removeObjectAtIndex:i];
	}
    }
  
//  PCLogInfo(self, @"{addSubproject} %@", files);

  if (![fileManager copyFiles:files
                intoDirectory:[activeProject projectPath]])
    {
      return NO;
    }

  for (i = 0; i < [files count]; i++)
    {
      spDir = [files objectAtIndex:i];
      pcProject = [spDir stringByAppendingPathComponent:@"PC.project"];
      spDict = [NSDictionary dictionaryWithContentsOfFile:pcProject];
      spName = [spDict objectForKey:PCProjectName];
      
//      PCLogInfo(self, @"{addSubproject} dir: %@ file: %@", spDir, pcProject);
	
      [activeProject addSubprojectWithName:spName];
    }

  return YES;
}

@end

