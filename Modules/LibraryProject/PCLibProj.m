/*
   GNUstep ProjectCenter - http://www.gnustep.org

   Copyright (C) 2001-2004 Free Software Foundation

   Authors: Philippe C.D. Robert
            Serg Stoyan
	    
   Description: Creates new project of the type Library!

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
   Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA
*/

#include <ProjectCenter/PCFileCreator.h>
#include <ProjectCenter/PCMakefileFactory.h>

#include "PCLibProj.h"
#include "PCLibProject.h"

@implementation PCLibProj

static PCLibProj *_creator = nil;

//----------------------------------------------------------------------------
// ProjectType
//----------------------------------------------------------------------------

+ (id)sharedCreator
{
  if (!_creator)
    {
      _creator = [[[self class] alloc] init];
    }

  return _creator;
}

- (Class)projectClass
{
  return [PCLibProject class];
}

- (NSString *)projectTypeName
{
  return @"Library";
}

- (PCProject *)createProjectAt:(NSString *)path
{
  PCLibProject  *project = nil;
  NSFileManager *fm = [NSFileManager defaultManager];

  NSAssert(path,@"No valid project path provided!");

  if ([fm createDirectoryAtPath:path attributes:nil])
    {
      NSBundle            *projectBundle = nil;
      NSMutableDictionary *projectDict;
      NSString            *projectName = nil;
      NSString            *_file = nil;
      NSString            *_2file = nil;
//      NSString            *_lresourcePath;
      NSString            *_resourcePath;
      PCFileCreator       *pcfc = [PCFileCreator sharedCreator];

      project = [[[PCLibProject alloc] init] autorelease];
      projectBundle = [NSBundle bundleForClass:[self class]];

      _file = [projectBundle pathForResource:@"PC" ofType:@"project"];
      projectDict = [NSMutableDictionary dictionaryWithContentsOfFile:_file];

      // Customise the project
      projectName = [path lastPathComponent];
      if ([[projectName pathExtension] isEqualToString:@"subproj"])
	{
	  projectName = [projectName stringByDeletingPathExtension];
	}
      [projectDict setObject:projectName forKey:PCProjectName];
      [projectDict setObject:[self projectTypeName] forKey:PCProjectType];
      [projectDict setObject:[[NSCalendarDate date] description]
	              forKey:PCCreationDate];
      [projectDict setObject:NSFullUserName() forKey:PCProjectCreator];
      [projectDict setObject:NSFullUserName() forKey:PCProjectMaintainer];
      // The path cannot be in the PC.project file!
      [project setProjectPath:path];
      [project setProjectName:projectName];

      // Copy the project files to the provided path

      // $PROJECTNAME$.m
      _file = [NSString stringWithFormat:@"%@", projectName];
      _2file = [NSString stringWithFormat:@"%@.m", projectName];
      [pcfc createFileOfType:ObjCClass 
	                path:[path stringByAppendingPathComponent:_file]
		     project:project];
      [projectDict setObject:[NSArray arrayWithObjects:_2file,nil]
	              forKey:PCClasses];

      // $PROJECTNAME$.h already created by creating $PROJECTNAME$.m
      _file = [NSString stringWithFormat:@"%@.h", projectName];
      [projectDict setObject:[NSArray arrayWithObjects:_file,nil]
	              forKey:PCHeaders];
      [projectDict setObject:[NSArray arrayWithObjects:_file,nil]
	              forKey:PCPublicHeaders];

      // GNUmakefile.postamble
      [[PCMakefileFactory sharedFactory] createPostambleForProject:project];

      // Resources
/*      _lresourcePath = [path stringByAppendingPathComponent:@"English.lproj"];
      [fm createDirectoryAtPath:_resourcePath attributes:nil];*/
      
      _resourcePath = [path stringByAppendingPathComponent:@"Resources"];
      [fm createDirectoryAtPath:_resourcePath attributes:nil];

      _file = [projectBundle pathForResource:@"Version" ofType:@""];
      _2file = [_resourcePath stringByAppendingPathComponent:@"Version"];
      [fm copyPath:_file toPath:_2file handler:nil];

      // Set the new dictionary - this causes the GNUmakefile 
      // to be written to disc
      if (![project assignProjectDict:projectDict])
	{
	  NSRunAlertPanel(@"Attention!",
			  @"Could not load %@!",
			  @"OK",nil,nil,path);
	  return nil;
	}

      // Save the project to disc
      [project save];
    }

  return project;
}

- (PCProject *)openProjectAt:(NSString *)path
{
  NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile:path];
  NSString     *pPath = [path stringByDeletingLastPathComponent];

  return [[[PCLibProject alloc] initWithProjectDictionary:dict 
                                                     path:pPath] autorelease];

  return nil;
}

@end
