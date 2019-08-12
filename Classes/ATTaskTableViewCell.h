//
//  ATTaskTableViewCell.h
//  Installer
//
//  Created by DigitalStealth on 21.07.08.
//  Copyright 2008 DIGITAL STEALTH DESIGN GROUP. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "ATInstaller.h"
#import "ATPipeline.h"
#import "ATPipelineManager.h"
#import "ATTableViewCell.h"

typedef enum {
	ATTaskTableCellDownload = 0,
	ATTaskTableCellInstall = 1,
	ATTaskTableCellRefresh = 2
} ATTaskTableCellTypes;



typedef enum {
//	ATTaskTableCellStatusPause = 0,
	ATTaskTableCellStatusFail = 1,
	ATTaskTableCellStatusActive = 2,
	ATTaskTableCellStatusDone = 3,
	ATTaskTableCellStatusIdle = 4,
//	ATTaskTableCellStatusStopByUser = 5
} ATTaskTableCellStatus;



@interface ATTaskTableViewCell : ATTableViewCell {
	UILabel *taskName;
	UILabel *taskDescription;
	UILabel *taskStatus;
	UILabel *taskStatusLabel;
	ATTaskTableCellStatus status;
	bool isProgressShown;
	bool isIndicatorShown;
	UIProgressView *progress;
	UIActivityIndicatorView *indicator;
	UIImageView *iconView;
	
}
@property (readonly) ATTaskTableCellStatus status;

- (void) setType:(ATTaskTableCellTypes)type;
- (void) setTitle:(NSString*)title;
- (void) setDescription:(NSString*)descr;
- (void) setStatus:(ATTaskTableCellStatus)st;
- (void) setShowProgress:(bool)show;
- (void) setProgress:(float)pr;
- (void) _didEndHideIndicatorAnimation:(id)sender;
- (void) _didEndHideProgressAnimation:(id)sender;

@end
