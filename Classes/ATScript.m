// AppTapp Framework
// Copyright 2007 Nullriver, Inc.

#import "ATScript.h"
#import "ATPackage.h"
#import "ATLuaScript.h"

@implementation ATScript

@synthesize delegate;
@synthesize unpacker;
@synthesize protectedPaths;
@synthesize scriptAbortedGracefully;
@synthesize package;
@synthesize lua;

#pragma mark Factory

- (id)initWithDelegate:(id)del {
	if(self = [super init]) {
		self.scriptCommands = [[NSMutableArray alloc] init];
		self.scriptAbortedGracefully = NO;
		self.delegate = del;
	}

	return self;
}


- (void)dealloc {
	self.package = nil;
	self.delegate = nil;
	self.scriptCommands = nil;
	self.unpacker = nil;
	self.lua = nil;

	[super dealloc];
}


#pragma mark -
#pragma mark Accessors

- (void)setPackage:(ATPackage *)aPackage {
	if(aPackage != nil) {
		[aPackage retain];
		[package release];
		package = aPackage;
		
		NSString* packageFileName = [self.delegate packageFileNameForScript:self];
		
		if (packageFileName)
			self.unpacker = [[[ATUnpacker alloc] initWithPath:packageFileName packageID:package.identifier] autorelease];
	}
}

- (void)setScriptCommands:(NSMutableArray *)commands {
	[scriptCommands removeAllObjects];
	[scriptCommands addObjectsFromArray:commands];
}

- (NSMutableArray*)scriptCommands
{
	return scriptCommands;
}

- (BOOL)scriptAbortedGracefully {
	return scriptAbortedGracefully;
}

- (int)dialect {
	return 500;
}

#pragma mark -
#pragma mark Methods

- (BOOL)run {
	return [self runScript:scriptCommands withError:nil];
}

- (BOOL)runScript:(NSArray *)theScript withError:(NSError**)outError {
	scriptAbortedGracefully = NO;

	//Log(@"ATScript: Running script, dialect is: %i", [self dialect]);
	if ([self.delegate respondsToSelector:@selector(scriptDidChangeProgress:progress:)])
		[delegate performSelector:@selector(scriptDidChangeProgress:progress:) withObject:self withObject:[NSNumber numberWithInt:0]];

	BOOL result = YES;
	int count = 0;
	int percent = 0;
	int line = 0;

	for(NSArray * command in theScript) {
		NSString * commandName = [command objectAtIndex:0];
		NSArray * arguments = [command subarrayWithRange:NSMakeRange(1, [command count] - 1)];

		line++;
		
		Log(@"Executing script instruction: %@ with arguments %@", commandName, arguments);

		NSString* errDesc = nil;
		NSString* selectorName = [NSString stringWithFormat:@"script_%@:error:", commandName];
		SEL sel = NSSelectorFromString(selectorName);
		
		if (!sel || ![self respondsToSelector:sel])
			sel = NSSelectorFromString([NSString stringWithFormat:@"script_%@:", commandName]);
		
		if (sel && [self respondsToSelector:sel])
			result = (int)[self performSelector:sel withObject:arguments withObject:(id)&errDesc];
		else {
			// The error message should be improved for If/IfNot
			NSDictionary* userInfo = [NSDictionary dictionaryWithObjectsAndKeys:	[NSString stringWithFormat:@"Unknown script command on line %d:\n\n%@", line, commandName],		NSLocalizedDescriptionKey,
																					theScript,	@"script",
																					nil];
			NSError* error = [NSError errorWithDomain:AppTappErrorDomain code:kATErrorScriptError userInfo:userInfo];

			result = NO;
			
			if (outError)
				*outError = error;
		}

		if (result == NO)
		{
			if (!scriptAbortedGracefully)
			{
				NSString* fullCommandName = [arguments componentsJoinedByString:@", "];
				NSMutableString* fcnFull = [NSMutableString stringWithCapacity:0];
				[fcnFull appendString:fullCommandName];
				
				if ([fcnFull length] > 120)
				{
					[fcnFull deleteCharactersInRange:NSMakeRange(120, [fcnFull length]-120)];
					[fcnFull appendString:@"…"];
				}
				
				NSString* locDesc = errDesc;
				
				if (!locDesc)
					locDesc = [NSString stringWithFormat:@"Failed script command on line %d:\n\n%@", line, [NSString stringWithFormat:@"%@(%@)", commandName, fcnFull]];
				
				NSDictionary* userInfo = [NSDictionary dictionaryWithObjectsAndKeys:	locDesc,		NSLocalizedDescriptionKey,
																						theScript,	@"script",
																						nil];
				NSError* error = [NSError errorWithDomain:AppTappErrorDomain code:kATErrorScriptError userInfo:userInfo];
				
				if (outError)
					*outError = error;
			}
		
			return NO;
		}
		
		count++;
		percent = (count / [[NSNumber numberWithUnsignedInt:[theScript count]] doubleValue]) * 100;
		if ([self.delegate respondsToSelector:@selector(scriptDidChangeProgress:progress:)])
			[delegate performSelector:@selector(scriptDidChangeProgress:progress:) withObject:self withObject:[NSNumber numberWithInt:percent]];
		[[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.01f]];
	}
	
	return result;
}


#pragma mark -
#pragma mark Script Commands

- (BOOL)script_SetStatus:(NSArray *)arguments {
	if([arguments count] != 1) return NO; // SetStatus(text)

	if ([self.delegate respondsToSelector:@selector(scriptDidChangeStatus:status:)])
		[self.delegate performSelector:@selector(scriptDidChangeStatus:status:) withObject:self withObject:[arguments objectAtIndex:0]];

	return YES;
}

- (BOOL)script_Notice:(NSArray *)arguments {
	if([arguments count] != 1) return NO; // Notice(text)

	if ([self.delegate respondsToSelector:@selector(scriptIssueNotice:notice:)])
		[self.delegate performSelector:@selector(scriptIssueNotice:notice:) withObject:self withObject:[arguments objectAtIndex:0]];

	while (![[self.delegate performSelector:@selector(scriptCanContinue:) withObject:self] boolValue]) {
		NSAutoreleasePool* innerPool = [[NSAutoreleasePool alloc] init];
		[[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.1f]];
		[innerPool release];
	}

	return YES;
}

- (BOOL)script_Confirm:(NSArray *)arguments {
	if([arguments count] != 3) return NO; // Confirm(text, button1, button2)

	if ([self.delegate respondsToSelector:@selector(scriptIssueConfirmation:arguments:)])
		[self.delegate performSelector:@selector(scriptIssueConfirmation:arguments:) withObject:self withObject:arguments];

	while(![[self.delegate performSelector:@selector(scriptCanContinue:) withObject:self] boolValue]) {
		NSAutoreleasePool* innerPool = [[NSAutoreleasePool alloc] init];
		[[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.1f]];
		[innerPool release];
	}

	unsigned button = [[self.delegate performSelector:@selector(scriptConfirmationButton:) withObject:self] unsignedIntValue];

	if(button == 1) return YES;
	else {
		self.scriptAbortedGracefully = YES;
		return NO;
	}
}

- (BOOL)script_AbortOperation:(NSArray *)arguments {
	if([arguments count] != 1) return NO; // AbortOperation(text)

	if ([self.delegate respondsToSelector:@selector(scriptIssueError:error:)])
		[self.delegate performSelector:@selector(scriptIssueError:error:) withObject:self withObject:[arguments objectAtIndex:0]];

	while(![[self.delegate performSelector:@selector(scriptCanContinue:) withObject:self] boolValue]) {
		NSAutoreleasePool* innerPool = [[NSAutoreleasePool alloc] init];
		[[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.1f]];
		[innerPool release];
	}

	self.scriptAbortedGracefully = YES;

	return NO;
}

- (BOOL)script_MinDialect:(NSArray *)arguments {
	if([arguments count] != 1) return NO; // MinDialect(dialectNumber)

	return ([[arguments objectAtIndex:0] intValue] < [self dialect]);
}

- (BOOL)script_FreeSpaceAtPath:(NSArray *)arguments {
	if([arguments count] != 2) return NO; // FreeSpaceAtPath(path, minimumSpace)

	NSString * path = [[arguments objectAtIndex:0] stringByExpandingSpecialPathsInPath];

	return [[[NSFileManager defaultManager] freeSpaceAtPath:path] unsignedLongLongValue] >= (unsigned long long)([[arguments objectAtIndex:1] intValue] * 1024);
}

- (BOOL)script_ExistsPath:(NSArray *)arguments {
	if([arguments count] != 1) return NO; // ExistsPath(path)
	NSString * path = [[arguments objectAtIndex:0] stringByExpandingSpecialPathsInPath];

	return [[NSFileManager defaultManager] fileExistsAtPath:path];
}

- (BOOL)script_IsLink:(NSArray *)arguments {
	if([arguments count] != 1) return NO; // IsLink(path)
	NSString * path = [[arguments objectAtIndex:0] stringByExpandingSpecialPathsInPath];

	return [[[[NSFileManager defaultManager] attributesOfItemAtPath:path error:nil] valueForKey:NSFileTypeSymbolicLink] boolValue];
}

- (BOOL)script_IsFolder:(NSArray *)arguments {
	if([arguments count] != 1) return NO; // IsFolder(path)
	NSString * path = [[arguments objectAtIndex:0] stringByExpandingSpecialPathsInPath];

	return [[[[NSFileManager defaultManager] attributesOfItemAtPath:path error:nil] valueForKey:NSFileTypeDirectory] boolValue];
}

- (BOOL)script_IsFile:(NSArray *)arguments {
	if([arguments count] != 1) return NO; // IsFile(path)
	NSString * path = [[arguments objectAtIndex:0] stringByExpandingSpecialPathsInPath];

	return [[[[NSFileManager defaultManager] attributesOfItemAtPath:path error:nil] valueForKey:NSFileTypeRegular] boolValue];
}

- (BOOL)script_IsExecutable:(NSArray *)arguments {
	if([arguments count] != 1) return NO; // IsExecutable(path)
	NSString * path = [[arguments objectAtIndex:0] stringByExpandingSpecialPathsInPath];

	return [[NSFileManager defaultManager] isExecutableFileAtPath:path];
}

- (BOOL)script_IsWritable:(NSArray *)arguments {
	if([arguments count] != 1) return NO; // IsWritable(path)
	NSString * path = [[arguments objectAtIndex:0] stringByExpandingSpecialPathsInPath];

	return [[NSFileManager defaultManager] isWritableFileAtPath:path];
}

- (BOOL)script_InstalledPackage:(NSArray *)arguments {
	if([arguments count] != 1) return NO; // InstalledPackage(packageBundleIdentifier)

	return [[delegate performSelector:@selector(scriptIsPackageInstalled:) withObject:[arguments objectAtIndex:0]] boolValue];
}

- (BOOL)script_InstallApp:(NSArray *)arguments {
	if([arguments count] != 1) return NO; // InstallApp(source)

	NSArray * newArguments = [NSArray arrayWithObjects:
					[arguments objectAtIndex:0],
					[[ATPlatform applicationsPath] stringByAppendingPathComponent:[arguments objectAtIndex:0]], 
				nil];

	Log(@"ATScript: Installing App: %@", [newArguments objectAtIndex:1]);
	return [self script_CopyPath:newArguments];
}

- (BOOL)script_UninstallApp:(NSArray *)arguments {
	if([arguments count] != 1) return NO; // UninstallApp(appBundle)

	NSString * appBundle = [arguments objectAtIndex:0];

	if(![appBundle isEqualToString:@""]) {
		NSArray * newArguments = [NSArray arrayWithObject:[[ATPlatform applicationsPath] stringByAppendingPathComponent:appBundle]];
		Log(@"ATScript: Uninstalling App: %@", [newArguments objectAtIndex:0]);
		return [self script_RemovePath:newArguments];
	} else {
		Log(@"ATScript: Cannot UninstallApp, no bundle specified!");
		return NO;
	}
}

- (BOOL)script_CopyPath:(NSArray *)arguments {
	if([arguments count] != 2) return NO; // CopyPath(source, destination)

	NSString * path1 = [[arguments objectAtIndex:0] stringByExpandingSpecialPathsInPath];
	NSString * path2 = [[arguments objectAtIndex:1] stringByExpandingSpecialPathsInPath];

	if([path1 isAbsolutePath]) {
		Log(@"ATScript: Copying absolute path: %@ to: %@", path1, path2);
		return [[NSFileManager defaultManager] copyPath:path1 toPath:path2 handler:nil];
	} else {
		BOOL res;
		
		NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
		res = [unpacker copyCompressedPath:path1 toFileSystemPath:path2];
		[pool release];
		
		return res;
	}
}

- (BOOL)script_MovePath:(NSArray *)arguments {
	if([self script_CopyPath:arguments]) {
		return [self script_RemovePath:[NSArray arrayWithObject:[arguments objectAtIndex:0]]];
	}

	return NO;
}

- (BOOL)script_LinkPath:(NSArray *)arguments {
	if([arguments count] != 2) return NO; // LinkPath(fromPath, toPath)

	NSString * path1 = [[arguments objectAtIndex:0] stringByExpandingSpecialPathsInPath];
	NSString * path2 = [[arguments objectAtIndex:1] stringByExpandingSpecialPathsInPath];
	NSError* error = nil;
	
	return [[NSFileManager defaultManager] createSymbolicLinkAtPath:path2 withDestinationPath:path1 error:&error];
}

- (BOOL)script_ChangeMode:(NSArray*)arguments {
	if ([arguments count] != 2) return NO;		// ChangeMode(path, mode)
	
	NSString * path = [[arguments objectAtIndex:0] stringByExpandingSpecialPathsInPath];
	NSString * modeStr = [arguments objectAtIndex:1];
	unsigned int mode = 0;
	NSError * error = nil;
	
	if (sscanf([modeStr UTF8String], "%o", &mode) != 1)
		mode = 0777;
		
	Log(@"ATScript: ChangeMode(%@, %o)", path, mode);
	
	NSDictionary * attr = [NSDictionary dictionaryWithObject:[NSNumber numberWithUnsignedInt:mode] forKey:NSFilePosixPermissions];
	
	return [[NSFileManager defaultManager] setAttributes:attr ofItemAtPath:path error:&error];
}

- (BOOL)script_ChangeModeRecursive:(NSArray*)arguments {
	if ([arguments count] != 2) return NO;		// ChangeMode(path, mode)
	
	NSString * path = [[arguments objectAtIndex:0] stringByExpandingSpecialPathsInPath];
	NSString * modeStr = [arguments objectAtIndex:1];
	unsigned int mode = 0;
	NSError * error = nil;
	
	if (sscanf([modeStr UTF8String], "%o", &mode) != 1)
		mode = 0777;
		
	Log(@"ATScript: ChangeModeRecursive(%@, %o)", path, mode);
	
	NSDictionary * attr = [NSDictionary dictionaryWithObject:[NSNumber numberWithUnsignedInt:mode] forKey:NSFilePosixPermissions];
	
	NSDirectoryEnumerator* en = [[NSFileManager defaultManager] enumeratorAtPath:path];
	if (en)
	{
		NSString* filename;
		
		while (filename = [en nextObject])
		{
			[[NSFileManager defaultManager] setAttributes:attr ofItemAtPath:[path stringByAppendingPathComponent:filename] error:&error];
		}
	}
	
	return [[NSFileManager defaultManager] setAttributes:attr ofItemAtPath:path error:&error];
}


- (BOOL)script_ChangeOwner:(NSArray*)arguments {
	if ([arguments count] < 2) return NO;		// ChangeOwnerRecursively(path, owner, [group])
	
	NSString * path = [[arguments objectAtIndex:0] stringByExpandingSpecialPathsInPath];
	NSString * owner = [arguments objectAtIndex:1];
	NSString * group = nil;
	
	if ([arguments count] > 2)
		group = [arguments objectAtIndex:2];
	
	Log(@"ATScript: ChangeOwnerRecursively(%@, %@, %@)", path, owner, group);
	
	NSDictionary * attr = nil;
	NSError* error = nil;
	
	if (group)
		attr = [NSDictionary dictionaryWithObjectsAndKeys:owner, NSFileOwnerAccountName, group, NSFileGroupOwnerAccountName, nil];
	else
		attr = [NSDictionary dictionaryWithObject:owner forKey:NSFileOwnerAccountName];
	
	[[NSFileManager defaultManager] setAttributes:attr ofItemAtPath:path error:&error];
	
	NSDirectoryEnumerator* en = [[NSFileManager defaultManager] enumeratorAtPath:path];
	if (en)
	{
		NSString* filename;
		
		while (filename = [en nextObject])
		{
			[[NSFileManager defaultManager] setAttributes:attr ofItemAtPath:[path stringByAppendingPathComponent:filename] error:&error];
		}
	}
	
	return YES;
}

- (BOOL)script_RemovePath:(NSArray *)arguments {
	if([arguments count] < 1) return NO; // RemovePath(path, ...)

	NSEnumerator * allArguments = [arguments objectEnumerator];
	NSString * path;
	while((path = [[allArguments nextObject] stringByExpandingSpecialPathsInPath])) {
		// sanity check
		if([path isEqualToString:@"/"]) return NO; // hell no

		// Record the removal if this is an app
#if !defined(ATCORE)
		if ([[path pathExtension] isEqualToString:@"app"] && [[NSFileManager defaultManager] fileExistsAtPath:path])
		{
			NSBundle* bundleToRemove = [NSBundle bundleWithPath:path];
			NSDictionary* infoDict = [bundleToRemove infoDictionary];

            if (infoDict != nil)
                [[ATPackageManager sharedPackageManager].removedApplications addObject:infoDict];
		}
#endif
		
		// Fail only if the file exists and cannot be removed
		if(
			[[NSFileManager defaultManager] fileExistsAtPath:path] &&
			![[NSFileManager defaultManager] removeItemAtPath:path error:nil]
		) return NO;
	}

	return YES;
}

- (BOOL)script_Exec:(NSArray *)arguments {
	if([arguments count] < 1) return NO; // Exec(path)

	if ([arguments count] == 1)
		arguments = [[arguments objectAtIndex:0] componentsSeparatedByString:@" "];

	NSString * command = [[arguments objectAtIndex:0] stringByExpandingSpecialPathsInPath];

	NSArray * commandArguments = arguments; //[NSMutableArray arrayWithObject:[command lastPathComponent]];
	//[commandArguments addObjectsFromArray:[arguments subarrayWithRange:NSMakeRange(1, [arguments count] - 1)]];

	// generate argv
	unsigned arrayCount = [commandArguments count];
	char *argv[arrayCount + 1];
	int argvCount;

	for (argvCount = 0; argvCount < arrayCount; argvCount++) {
		NSString *theString = (NSString *)[commandArguments objectAtIndex:argvCount];
		unsigned int stringLength = [theString length];

		argv[argvCount] = malloc((stringLength + 1) * sizeof(char));
		snprintf(argv[argvCount], stringLength + 1, "%s", [theString fileSystemRepresentation]);
	}
	argv[argvCount] = NULL;

	// begin

	pid_t pid;
	pid_t result;
	int status;

	pid = fork();

	if(pid == 0) {
		execv([command fileSystemRepresentation], argv);
		exit(1);
	} else if(pid < 0) {
		Log(@"Error forking child process!");
	} else {
		while((result = wait(&status))) { if(result == pid || result == -1) break; }
		if(status == 0) return YES;
	}

	return NO;
}

- (BOOL)script_ExecNoError:(NSArray *)arguments {
	[self script_Exec:arguments];

	return YES;
}

- (BOOL)script_If:(NSArray *)arguments {
	if([arguments count] != 2) return NO; // If(evalScript, trueScript)
	
	NSArray * evalScript = [arguments objectAtIndex:0];
	NSArray * trueScript = [arguments objectAtIndex:1];

	if(
		![evalScript respondsToSelector:@selector(sortedArrayHint)] ||
		![trueScript respondsToSelector:@selector(sortedArrayHint)]
	) {
		Log(@"Error: Invalid arguments to If!");
		return NO;
	}

	if([self runScript:evalScript withError:nil]) {
		return [self runScript:trueScript withError:nil];
	}

	scriptAbortedGracefully = NO;

	return YES;
}

- (BOOL)script_IfNot:(NSArray *)arguments {
	if([arguments count] != 2) return NO; // If(evalScript, falseScript)
	
	NSArray * evalScript = [arguments objectAtIndex:0];
	NSArray * falseScript = [arguments objectAtIndex:1];

	if(
		![evalScript respondsToSelector:@selector(sortedArrayHint)] ||
		![falseScript respondsToSelector:@selector(sortedArrayHint)]
	) {
		Log(@"Error: Invalid arguments to IfNot!");
		return NO;
	}

	if(![self runScript:evalScript withError:nil]) {
		return [self runScript:falseScript withError:nil];
	}

	scriptAbortedGracefully = NO;

	return YES;
}

- (BOOL)script_AddSource:(NSArray *)arguments {
	if([arguments count] != 1) return NO; // AddSource(url)

	if ([self.delegate respondsToSelector:@selector(script:removeSource:)])
		[self.delegate performSelector:@selector(script:addSource:) withObject:self withObject:[arguments lastObject]];

	return YES;
}

- (BOOL)script_RemoveSource:(NSArray *)arguments {
	if([arguments count] != 1) return NO; // RemoveSource(url)

	if ([self.delegate respondsToSelector:@selector(script:removeSource:)])
		[self.delegate performSelector:@selector(script:removeSource:) withObject:self withObject:[arguments lastObject]];

	return YES;
}

- (BOOL)script_RestartSpringBoard:(NSArray*)arguments {
	// RestartSpringBoard()
	
	if ([self.delegate respondsToSelector:@selector(scriptRestartSpringBoard:)])
		[self.delegate performSelector:@selector(scriptRestartSpringBoard:) withObject:self];

	return YES;
}

- (BOOL)script_PlatformNameIs:(NSArray *)arguments {
	// PlatformNameIs(arrayOfVersions)
	return [[arguments objectAtIndex:0] containsObject:[ATPlatform platformName]];
}

- (BOOL)script_FirmwareVersionIs:(NSArray *)arguments {
	// FirmwareVersionIs(arrayOfVersions)
	return [[arguments objectAtIndex:0] containsObject:[ATPlatform firmwareVersion]];
}

- (BOOL)script_DeviceRootLocked:(NSArray*)arguments {
	return [ATPlatform isDeviceRootLocked];
}

- (BOOL)script_RunScript:(NSArray *)arguments error:(NSString**)errorDesc
{
	if([arguments count] != 1) return NO; // RunScript(scriptName)
	
	if (!self.lua)
	{
		self.lua = [[[ATLuaScript alloc] init] autorelease];
		self.lua.script = self;
	}
	
	if ([[arguments objectAtIndex:0] isKindOfClass:[NSData class]])
	{
		NSData* scriptData = [arguments objectAtIndex:0];
		
		return [self.lua runScriptData:scriptData error:errorDesc];
	}
	else
	{	
		NSString * path1 = [[arguments objectAtIndex:0] stringByExpandingSpecialPathsInPath];

		if([path1 isAbsolutePath])
		{
			Log(@"ATScript: Running script at absolute path: %@", path1);
			return [self.lua runScript:path1 error:errorDesc];
		}
		else
		{
			NSString* tempPath = [[NSFileManager defaultManager] tempFilePath];
			if ([unpacker copyCompressedPath:path1 toFileSystemPath:tempPath])
			{
				BOOL result = [self.lua runScript:tempPath error:errorDesc];
				[[NSFileManager defaultManager] removeItemAtPath:tempPath error:nil];
				
				return result;
			}
			else
			{
				Log(@"ATScript: cannot extract the file %@", path1);
				if (errorDesc)
					*errorDesc = [NSString stringWithFormat:@"Can't extract the script at %@", path1];
				return NO;
			}
		}
	}
	
	return YES;
}

@end
