// AppTapp Framework
// Copyright 2007 Nullriver, Inc.


#import "ATPlatform.h"
#import "ATUnpacker.h"

@class ATPackage;
@class ATLuaScript;

@interface ATScript : NSObject {
	id delegate;
	ATPackage * package;
	NSMutableArray * scriptCommands;
	ATUnpacker * unpacker;
	NSArray * protectedPaths;
	BOOL scriptAbortedGracefully;
	ATLuaScript* lua;
}

@property (assign) id delegate;
@property (retain) ATPackage * package;
@property (retain) NSMutableArray * scriptCommands;
@property (retain) ATUnpacker * unpacker;
@property (retain) NSArray * protectedPaths;
@property (assign) BOOL scriptAbortedGracefully;
@property (retain) ATLuaScript* lua;

- (id)initWithDelegate:(id)del;

// Accessors
- (int)dialect;

// Methods
- (BOOL)run;
- (BOOL)runScript:(NSArray *)theScript withError:(NSError**)outError;

// Script Commands
- (BOOL)script_SetStatus:(NSArray *)arguments;					// supported in lua
- (BOOL)script_Notice:(NSArray *)arguments;						// supported in lua
- (BOOL)script_Confirm:(NSArray *)arguments;					// supported in lua
- (BOOL)script_AbortOperation:(NSArray *)arguments;				// supported in lua
- (BOOL)script_MinDialect:(NSArray *)arguments;
- (BOOL)script_FreeSpaceAtPath:(NSArray *)arguments;
- (BOOL)script_ExistsPath:(NSArray *)arguments;					// supported in lua
- (BOOL)script_IsLink:(NSArray *)arguments;						// supported in lua
- (BOOL)script_IsFolder:(NSArray *)arguments;					// supported in lua
- (BOOL)script_IsFile:(NSArray *)arguments;						// supported in lua
- (BOOL)script_IsExecutable:(NSArray *)arguments;				// supported in lua
- (BOOL)script_IsWritable:(NSArray *)arguments;					// supported in lua
- (BOOL)script_InstalledPackage:(NSArray *)arguments;			// supported in lua
- (BOOL)script_CopyPath:(NSArray *)arguments;					// supported in lua
- (BOOL)script_MovePath:(NSArray *)arguments;					// supported in lua
- (BOOL)script_LinkPath:(NSArray *)arguments;					// supported in lua
- (BOOL)script_RemovePath:(NSArray *)arguments;					// supported in lua
- (BOOL)script_ChangeMode:(NSArray*)arguments;					// supported in lua
- (BOOL)script_ChangeModeRecursive:(NSArray*)arguments;					// supported in lua
- (BOOL)script_ChangeOwner:(NSArray*)arguments;					// supported in lua (note, to set with group, there's a separate flavor ChangeOwnerGroup())
- (BOOL)script_Exec:(NSArray *)arguments;
- (BOOL)script_ExecNoError:(NSArray *)arguments;
- (BOOL)script_InstallApp:(NSArray *)arguments;
- (BOOL)script_UninstallApp:(NSArray *)arguments;
- (BOOL)script_If:(NSArray *)arguments;
- (BOOL)script_IfNot:(NSArray *)arguments;
- (BOOL)script_AddSource:(NSArray *)arguments;					// supported in lua
- (BOOL)script_RemoveSource:(NSArray *)arguments;				// supported in lua
- (BOOL)script_RestartSpringBoard:(NSArray*)arguments;			// supported in lua
//- (BOOL)script_DeviceRootLocked;								// supported in lua
- (BOOL)script_PlatformNameIs:(NSArray *)arguments;				// supported in lua (sort of, installer.PlatformName() returns platform name)
- (BOOL)script_FirmwareVersionIs:(NSArray *)arguments;			// supported in lua (sort of, installer.FirmwareVersion() returns firmware version string and installer.FirmwareVersionAsNumber() returns version number)
- (BOOL)script_RunScript:(NSArray *)arguments error:(NSString**)error;

@end

// Delegate methods
@interface NSObject (ATScriptDelegate)

// Mandatory
- (NSString*)packageFileNameForScript:(ATScript*)script;
- (void)scriptIssueNotice:(ATScript*)script notice:(NSString*)notice;
- (void)scriptIssueError:(ATScript*)script error:(NSString*)error;
- (void)scriptIssueConfirmation:(ATScript*)script arguments:(NSArray*)args;
- (NSNumber*)scriptCanContinue:(ATScript*)script;
- (NSNumber*)scriptConfirmationButton:(ATScript*)script;

- (void)script:(ATScript*)script addSource:(NSString*)url;
- (void)script:(ATScript*)script removeSource:(NSString*)url;
- (void)scriptRestartSpringBoard:(ATScript*)script;

// Optional
- (void)scriptDidChangeProgress:(ATScript*)script progress:(NSNumber*)progress;
- (void)scriptDidChangeStatus:(ATScript*)script status:(NSString*)status;

@end
