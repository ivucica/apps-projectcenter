#
# GNUmakefile
#

include $(GNUSTEP_MAKEFILES)/common.make
GNUSTEP_INSTALLATION_DIR = $(GNUSTEP_SYSTEM_ROOT)


#
# Subprojects
#
SUBPROJECTS = \
        Library \
	Modules \

#
# Main application
#

PACKAGE_NAME = ProjectCenter
APP_NAME = ProjectCenter
ProjectCenter_APPLICATION_ICON = Images/ProjectCenter.tiff


#
# Additional libraries
#

ADDITIONAL_GUI_LIBS += -lProjectCenter 

#
# Resource files
#

ProjectCenter_RESOURCE_FILES = \
ProjectCenterInfo.plist \
Images/ProjectCenter.tiff \
Images/ButtonTile.tiff \
Images/FileC.tiff \
Images/FileCH.tiff \
Images/FileH.tiff \
Images/FileHH.tiff \
Images/FileM.tiff \
Images/FileMH.tiff \
Images/FileRTF.tiff \
Images/FileProject.tiff \
Images/Clean.tiff \
Images/Debug.tiff \
Images/Files.tiff \
Images/Find.tiff \
Images/Install.tiff \
Images/Build.tiff \
Images/Options.tiff \
Images/Run.tiff \
Images/Inspector.tiff \
Images/Stop.tiff \
Images/Editor.tiff \
Images/ProjectCenter_add.tiff \
Images/ProjectCenter_cvs.tiff \
Images/ProjectCenter_dist.tiff \
Images/ProjectCenter_documentation.tiff \
Images/ProjectCenter_profile.tiff \
Images/ProjectCenter_rpm.tiff \
Images/ProjectCenter_uml.tiff \
Images/classSuitcase.tiff \
Images/classSuitcaseH.tiff \
Images/genericSuitcase.tiff \
Images/genericSuitcaseH.tiff \
Images/headerSuitcase.tiff \
Images/headerSuitcaseH.tiff \
Images/helpSuitcase.tiff \
Images/helpSuitcaseH.tiff \
Images/iconSuitcase.tiff \
Images/iconSuitcaseH.tiff \
Images/librarySuitcase.tiff \
Images/librarySuitcaseH.tiff \
Images/nibSuitcase.tiff \
Images/nibSuitcaseH.tiff \
Images/otherSuitcase.tiff \
Images/otherSuitcaseH.tiff \
Images/projectSuitcase.tiff \
Images/projectSuitcaseH.tiff \
Images/soundSuitcase.tiff \
Images/soundSuitcaseH.tiff \
Images/subprojectSuitcase.tiff \
Images/subprojectSuitcaseH.tiff \
Modules/ApplicationProject/ApplicationProject.bundle \
Modules/BundleProject/BundleProject.bundle \
Modules/LibraryProject/LibraryProject.bundle \
Modules/RenaissanceProject/RenaissanceProject.bundle \
Modules/ToolProject/ToolProject.bundle


#
# Header files
#

ProjectCenter_HEADERS = \
PCAppController.h \
PCFindController.h \
PCInfoController.h \
PCLogController.h \
PCMenuController.h \
PCPrefController.h \
PCPrefController+UInterface.h

#
# Class files
#

ProjectCenter_OBJC_FILES = \
PCAppController.m \
PCFindController.m \
PCInfoController.m \
PCLogController.m \
PCMenuController.m \
PCPrefController.m \
PCPrefController+UInterface.m \
ProjectCenter_main.m

#
# C files
#

ProjectCenter_C_FILES = 

ADDITIONAL_OBJCFLAGS += -Wall -Werror
ADDITIONAL_INCLUDE_DIRS += -I./Library
ADDITIONAL_LIB_DIRS += -L./Library/$(GNUSTEP_OBJ_DIR)


include $(GNUSTEP_MAKEFILES)/aggregate.make
include $(GNUSTEP_MAKEFILES)/application.make

