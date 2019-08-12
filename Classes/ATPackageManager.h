// AppTapp Framework
// Copyright 2007 Nullriver, Inc.


#import "NSNumber+AppTappExtensions.h"
#import "ATSources.h"
#import "ATPackages.h"
#import "ATScript.h"
#import "ATPlatform.h"

@class ATSources;
@class ATPackages;
@class ATScript;
@class ATSearch;
@class ATIncompleteDownloads;

// This should be set BEFORE you call any AT* class to properly function. You can initialize it with a bitwise OR of any of the following flags:
enum {
	kATBehavior_NoGUI				= (1L << 1),				// run in GUIless mode: alerts and popups will be suppressed, and no source refreshes will be done
																// upon startup
	kATBehavior_NoNetwork			= (1L << 2),				// run in networkless mode, certain network operations will be suppressed (such as source refreshes upon startup)
};
extern NSUInteger	gATBehaviorFlags;


@interface ATPackageManager : NSObject {
	ATSources			*	sources;
	ATPackages			*	packages;
	ATSearch			*	search;
	ATIncompleteDownloads * incompleteDownloads;
	BOOL					springboardNeedsRefresh;
	BOOL					springboardNeedsHardRefresh;
	id						delegate;
	BOOL					scriptCanContinue;
	NSUInteger				scriptConfirmationButton;
	
	NSMutableArray		*	installedApplications;
	NSMutableArray		*	removedApplications;
}


@property (nonatomic, retain) ATSources * sources;
@property (nonatomic, retain) ATPackages * packages;
@property (nonatomic, retain) ATSearch * search;
@property (nonatomic, assign) BOOL springboardNeedsRefresh;
@property (nonatomic, assign) BOOL springboardNeedsHardRefresh;
@property (nonatomic, assign) BOOL scriptCanContinue;
@property (nonatomic, assign) NSUInteger scriptConfirmationButton;
@property (nonatomic, assign) id delegate;
@property (nonatomic, retain) ATIncompleteDownloads * incompleteDownloads;

@property (retain) NSMutableArray* installedApplications;
@property (retain) NSMutableArray* removedApplications;

// Factory
+ (ATPackageManager*)sharedPackageManager;

// Methods
- (ATSource *)defaultSource;

- (BOOL)refreshIsNeeded;
- (BOOL)refreshTrustedSources;
- (BOOL)refreshAllSources;
- (BOOL)refreshSource:(ATSource *)aSource;

- (void)restartSpringBoardIfNeeded;
- (void)propogateMobileInstallation;

- (void)updateApplicationBadge;
@end
