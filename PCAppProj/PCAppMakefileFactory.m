/*
   GNUstep ProjectCenter - http://www.projectcenter.ch

   Copyright (C) 2000 Philippe C.D. Robert

   Author: Philippe C.D. Robert <phr@projectcenter.ch>

   This file is part of ProjectCenter.

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

#import "PCAppMakefileFactory.h"

@implementation PCAppMakefileFactory

static PCAppMakefileFactory *_factory = nil;

+ (PCAppMakefileFactory *)sharedFactory
{
    if (!_factory) {
        _factory = [[[self class] alloc] init];
    }
    return _factory;
}

- (NSData *)makefileForProject:(PCProject *)aProject;
{
    NSMutableString *string = [NSMutableString string];
    NSString *prName = [aProject projectName];
    NSDictionary *prDict = [aProject projectDict];
    NSString *tmp;
    NSEnumerator *enumerator;
    int i;
    
    // Header information
    [string appendString:@"#\n"];
    [string appendString:@"# GNUmakefile - Generated by the ProjectCenter\n"];
    [string appendString:@"# Written by Philippe C.D. Robert <phr@projectcenter.ch>\n"];
    [string appendString:@"#\n"];
    [string appendString:@"# NOTE: Do NOT change this file -- ProjectCenter maintains it!\n"];
    [string appendString:@"#\n"];
    [string appendString:@"# Put all of your customisations in GNUmakefile.preamble and\n"];
    [string appendString:@"# GNUmakefile.postamble\n"];
    [string appendString:@"#\n\n"];
    
    // The 'real' thing
    [string appendString:@"include $(GNUSTEP_MAKEFILES)/common.make\n"];

    [string appendString:@"#\n\n"];
    [string appendString:@"# Subprojects\n"];
    [string appendString:@"#\n\n"];

    if ([[aProject subprojects] count]) {
        enumerator = [[prDict objectForKey:PCSubprojects] objectEnumerator];
        while (tmp = [enumerator nextObject]) {
            [string appendString:[NSString stringWithFormat:@"\\\n%@ ",tmp]];
        }
    }

    [string appendString:@"#\n"];
    [string appendString:@"# Main application\n"];
    [string appendString:@"#\n\n"];

    [string appendString:[NSString stringWithFormat:@"APP_NAME=%@\n",prName]];
    // [string appendString:[NSString stringWithFormat:@"%@_PRINCIPAL_CLASS=%@\n",prName,[prDict objectForKey:PCPrincipalClass]]];
    //[string appendString:[NSString stringWithFormat:@"%@_MAIN_MODEL_FILE=%@\n",prName,[prDict objectForKey:PCMainGModelFile]]];
    [string appendString:[NSString stringWithFormat:@"%@_APPLICATION_ICON=%@\n",prName, [prDict objectForKey:PCAppIcon]]];

    [string appendString:@"#\n\n"];
    [string appendString:@"# Additional libraries\n"];
    [string appendString:@"#\n\n"];

    [string appendString:[NSString stringWithFormat:@"%@_ADDITIONAL_GUI_LIBS += ",prName]];

    if ([[prDict objectForKey:PCLibraries] count]) {
        enumerator = [[prDict objectForKey:PCLibraries] objectEnumerator];
        while (tmp = [enumerator nextObject]) {
	  if (![tmp isEqualToString:@"gnustep-base"] && 
	      ![tmp isEqualToString:@"gnustep-gui"]) {
	    [string appendString:[NSString stringWithFormat:@"-l%@ ",tmp]];
	  }
        }
    }

    [string appendString:@"\n\n#\n\n"];
    [string appendString:@"# Resource files\n"];
    [string appendString:@"#\n\n"];

    [string appendString:[NSString stringWithFormat:@"%@_RESOURCE_FILES= ",prName]];

    for (i=0;i<[[aProject resourceFileKeys] count];i++) {
        NSString *k = [[aProject resourceFileKeys] objectAtIndex:i];
        
        enumerator = [[prDict objectForKey:k] objectEnumerator];
        while (tmp = [enumerator nextObject]) {
            [string appendString:[NSString stringWithFormat:@"\\\nEnglish.lproj/%@ ",tmp]];
        }
    }

    [string appendString:[NSString stringWithFormat:@"\\\nInfo-project.plist "]];

    [string appendString:@"\n\n#\n\n"];
    [string appendString:@"# Header files\n"];
    [string appendString:@"#\n\n"];

    [string appendString:[NSString stringWithFormat:@"%@_HEADERS= ",prName]];

    enumerator = [[prDict objectForKey:PCHeaders] objectEnumerator];
    while (tmp = [enumerator nextObject]) {
        [string appendString:[NSString stringWithFormat:@"\\\n%@ ",tmp]];
    }

    [string appendString:@"\n\n#\n\n"];
    [string appendString:@"# Class files\n"];
    [string appendString:@"#\n\n"];

    [string appendString:[NSString stringWithFormat:@"%@_OBJC_FILES= ",prName]];

    enumerator = [[prDict objectForKey:PCClasses] objectEnumerator];
    while (tmp = [enumerator nextObject]) {
        [string appendString:[NSString stringWithFormat:@"\\\n%@ ",tmp]];
    }

    [string appendString:@"\n\n#\n\n"];
    [string appendString:@"# C files\n"];
    [string appendString:@"#\n\n"];

    [string appendString:[NSString stringWithFormat:@"%@_C_FILES= ",prName]];

    enumerator = [[prDict objectForKey:PCOtherSources] objectEnumerator];
    while (tmp = [enumerator nextObject]) {
        [string appendString:[NSString stringWithFormat:@"\\\n%@ ",tmp]];
    }

    [string appendString:@"\n\n"];

    [string appendString:@"-include GNUmakefile.preamble\n"];
    [string appendString:@"-include GNUmakefile.local\n"];
    [string appendString:@"include $(GNUSTEP_MAKEFILES)/aggregate.make\n"];
    [string appendString:@"include $(GNUSTEP_MAKEFILES)/application.make\n"];
    [string appendString:@"-include GNUmakefile.postamble\n"];

    return [string dataUsingEncoding:[NSString defaultCStringEncoding]];
}

@end
