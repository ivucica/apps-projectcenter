/*
   GNUstep ProjectCenter - http: //www.gnustep.org

   Copyright (C) 2001 Free Software Foundation

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

#include "PCInfoController.h"
#include "Library/ProjectCenter.h"

@implementation PCInfoController

- (id) init
{
  if ((self = [super init]))
    {
      NSString *file;

      file = [[NSBundle mainBundle] pathForResource: @"Info-gnustep" 
	ofType: @"plist"];

      infoDict = [NSDictionary dictionaryWithContentsOfFile: file];
      RETAIN(infoDict);
    }

  return self;
}

- (void) dealloc
{
  RELEASE(infoDict);

  if (infoWindow) 
    {
      RELEASE(infoWindow);
    }

  [super dealloc];
}

- (void) showInfoWindow: (id)sender
{
#if defined(GNUSTEP)
  if (!infoWindow)
    {
      infoWindow = [[GSInfoPanel alloc] initWithDictionary: infoDict];
    }

  [infoWindow setTitle: @"Info"];
  [infoWindow center];
  [infoWindow makeKeyAndOrderFront: self];
#else
  NSRunAlertPanel(@"Info",
		  @"OPENSTEP has no support for GSInfoPanel",
		  @"OK",nil,nil,nil);
#endif
}

@end
