/*
 *  Scythe.c
 *  Installer
 *
 *  Created by Slava Karpenko on 7/24/08.
 *  Copyright 2008 RiP Dev. All rights reserved.
 *
 */

#include <stdio.h>
#include <string.h>
#include <unistd.h>

int main(int argc, char * argv[])
{
	char fullpath[1024];
	
	strncpy(fullpath, argv[0], strlen(argv[0]) - strlen("Scythe"));
	strcat(fullpath, "Installer");
	
	char* newArgv[] = { fullpath, NULL };
	
	return execve(fullpath, newArgv, NULL);
}