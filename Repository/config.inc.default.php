<?php
/*
	Install 4.0 Repository
	© 2008, RiP Dev (Slava Karpenko)
	
	Please direct all questions on this code to slava@ripdev.com.
*/

define('REPOSITORY_URL', "http://yourdomain.com/");

// Various configuration tools for the repository
define('PACKAGES_PATH', "./packages");								  // local path to the packages directory
define('PACKAGES_PATH_URL', REPOSITORY_URL . "packages/");		  // fully qualified url to the packages (must have the trailing slash '/')
                                                                      
define('INFO_PATH', "./info");										  // local path to the package info directory. MUST BE WRITABLE BY THE HTTP USER!
define('INFO_PATH_URL', REPOSITORY_URL . "info/");				  // fully qualified url to the package info directory (must have the trailing slash '/')
                                                                      
define('CACHE_TTL', (60 * 60));										  // time to live for the cache (in seconds). new/updated packages will be loaded into the repo this often. don't set this too low or 
																	  // your repo server will be loaded. by default this is set to 1 hour.
																	  
define('CACHE_OLD_TTL', (60*60*24*3));								  // time to live for the old caches - keep this somewhere above 1 day but below a month, so indexes are not taking up too much space on your
																	  // hard drive
				
define('INCLUDE_ICONS', true);										  // should the repo include the icons found in the package zip files (Install.png) or not? May affect your bandwidth...
						                              
define('ENABLE_DEBUG', true);										// if set to true, you'll be able to see the repo contents by appending ?debug=1 to the URL.

define('SEARCH_ENABLED', true);										// Whether this repository should be included in Installer web searches (and be indexed with a crawler)

// Cache regeneration control. Calling regenerate.php will now regeneritory index files, so make sure you provide a good password and don't forget to update the firmware versions array when new firmware comes out.											
define('REGENERATE_SECRET', '');									  // THis is a secret key for your access to regenerate.php. Please define it to something non-obvious - you will be calling regenerate.php?secret=[yoursecretword]

//define('ZIP_CMDLINE_PATH', '/usr/bin/unzip');								// Only define/uncomment this if your unzip command line tool is not in the standard location (and regenerate.php complains).

global $POSSIBLE_FIRMWARE_VERSIONS;

// Update this array whenever new firmware comes out. The repository will serve empty list of packages for all other versions.
$POSSIBLE_FIRMWARE_VERSIONS = array( '2.0', '2.0.1' );

?>