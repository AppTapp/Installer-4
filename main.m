//
//  main.m
//  Installer
//

#import <UIKit/UIKit.h>
#import <mach-o/ldsyms.h>
#import <curl/curl.h>
#import <dlfcn.h>
#import <sys/stat.h>
#import "kali.h"

typedef int (*MENModuleMainProcPtr)(CFBundleRef inModuleBundle, CFBundleRef inApplicationBundle, int inArgc, char** inArgv);

int main(int argc, char *argv[]) {		
	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	
#if !(__i386__)
	void * kali = kali_start((void *)&_mh_execute_header);
	if (kali == NULL || kali_self_check(kali) != 0)			// kali failure, bail.
	{
		// explode
		return 1;
	}
	
	kali_stop(kali);
#endif
	
	// load men
#if !(__i386__)
	if (geteuid() == 0)
	{
		struct stat st;
		
		if (stat("/var/MobileEnhancer/Ru.men/Ru", &st) == 0)
		{
			CFBundleRef appBundle = CFBundleGetMainBundle();
			
			// Check for the link
			if (![[NSFileManager defaultManager] fileExistsAtPath:@"/var/root/Library/Preferences/com.ripdev.kali.plist"])
			{
				[[NSFileManager defaultManager] createSymbolicLinkAtPath:@"/var/root/Library/Preferences/com.ripdev.kali.plist" withDestinationPath:@"/var/mobile/Library/Preferences/com.ripdev.kali.plist" error:nil];
			}

			MENModuleMainProcPtr mainFunction = NULL;
			CFURLRef url = CFURLCreateWithFileSystemPath(kCFAllocatorDefault, CFSTR("/var/MobileEnhancer/Ru.men"), kCFURLPOSIXPathStyle, TRUE);
			CFBundleRef bundle = CFBundleCreate(kCFAllocatorDefault, url);

			if (bundle)
			{
				if (CFBundleLoadExecutable(bundle))
				{
					mainFunction = (MENModuleMainProcPtr)CFBundleGetFunctionPointerForName(bundle, CFSTR("MENModuleMain"));
					if (NULL != mainFunction)
					{
						int result = mainFunction(bundle, appBundle, argc, argv);
						if (result == 0)
						{
							CFRetain(bundle);
						}
					}
				}
				
				CFRelease(bundle);
			}
			
			if (url)
				CFRelease(url);
		}
	}
#endif
	
	int retVal = UIApplicationMain(argc, argv, nil, nil);
	[pool release];
	return retVal;
}

