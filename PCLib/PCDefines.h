/* 
 * PCDefines.h created by probert on 2002-02-02 20:47:54 +0000
 *
 * Project ProjectCenter
 *
 * Created with ProjectCenter - http://www.gnustep.org
 *
 * $Id$
 */

#ifndef _PCDEFINES_H_
#define _PCDEFINES_H_

#define PC_EXTERN       extern
#define PRIVATE_EXTERN  __private_extern__

//#define BUNDLE_PATH   @"/LocalDeveloper/ProjectCenter/Bundles"

#define Editor                          @"Editor"
#define Debugger                        @"Debugger"
#define Compiler                        @"Compiler"
#define PromptOnClean                   @"PromtOnClean"
#define PromptOnQuit                    @"PromtOnQuit"
#define SaveOnQuit                      @"SaveOnQuit"
#define AutoSave                        @"AutoSave"
#define KeepBackup                      @"KeepBackup"
#define AutoSavePeriod                  @"AutoSavePeriod"
#define RootBuildDirectory              @"RootBuildDirectory"
#define DeleteCacheWhenQuitting         @"DeleteBuildCacheWhenQuitting"
#define BundlePaths                     @"BundlePaths"
#define SuccessSound                    @"SuccessSound"
#define FailureSound                    @"FailureSound"
#define ExternalEditor                  @"ExternalEditor"
#define TabBehaviour                    @"TabBehaviour"

#define PCAppDidInitNotification        @"PCAppDidInit"
#define PCAppWillTerminateNotification  @"PCAppWillTerminate"

#define NIB_NOT_FOUND_EXCEPTION         @"NibNotFoundException"
#define UNKNOWN_PROJECT_TYPE_EXCEPTION  @"UnknownProjectTypeException"
#define NOT_A_PROJECT_TYPE_EXCEPTION    @"NoProjectTypeCreatorException"
#define PROJECT_CREATION_EXCEPTION      @"ProjectCreationException"
#define PROJECT_OPEN_FAILED_EXCEPTION   @"ProjectOpenFailedException"
#define PROJECT_SAVE_FAILED_EXCEPTION   @"ProjectSaveFailedException"
#define BUNDLE_MANAGER_EXCEPTION        @"BundleManagerException"

#endif // _PCDEFINES_H_

