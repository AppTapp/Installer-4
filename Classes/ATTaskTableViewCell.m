//
//  ATTaskTableViewCell.m
//  Installer
//
//  Created by DigitalStealth on 21.07.08.
//  Copyright 2008 DIGITAL STEALTH DESIGN GROUP. All rights reserved.
//

#import "ATTaskTableViewCell.h"

//extern UIImage *backShadowImage;

@implementation ATTaskTableViewCell

@synthesize status;

- (id)initWithFrame:(CGRect)frame reuseIdentifier:(NSString *)reuseIdentifier {
	if (self = [super initWithFrame:frame reuseIdentifier:reuseIdentifier]) {
		// Initialization code
		//if(backShadowImage == nil)
		//	backShadowImage = [[UIImage imageNamed:@"ATPCBackShadow.png"] retain];
		
		//UIImageView *backShadowImageView = [[UIImageView alloc] initWithImage:backShadowImage];
		//self.backgroundView = backShadowImageView;
		
		taskName = [[UILabel alloc] initWithFrame:CGRectMake(80, -3, 210, 35)];
		taskDescription = [[UILabel alloc] initWithFrame:CGRectMake(80, 23, 210, 20)];
		[taskName setTextColor:[UIColor blackColor]];
		[taskName setBackgroundColor:[UIColor clearColor]];
		taskName.shadowColor = [UIColor colorWithWhite:0.8 alpha:1.];
		taskName.shadowOffset = CGSizeMake(0,1);
		taskName.adjustsFontSizeToFitWidth = YES;
		taskName.numberOfLines = 1;
		taskName.minimumFontSize = 13.;
		taskName.font = [UIFont boldSystemFontOfSize:18.];
		
		UIFont *fontDescr = [UIFont fontWithName:@"Helvetica" size:12];
		[taskDescription setTextColor:[UIColor colorWithRed:.15 green:.3 blue:.45 alpha:1]];
		[taskDescription setBackgroundColor:[UIColor clearColor]];
		[taskDescription setFont:fontDescr];
		taskDescription.numberOfLines = 1;
		taskDescription.shadowColor = [UIColor colorWithWhite:0.8 alpha:1.];
		taskDescription.shadowOffset = CGSizeMake(0,1);
		
		taskStatusLabel = [[UILabel alloc] initWithFrame:CGRectMake(80, 40, 100, 20)];
		[taskStatusLabel setTextColor:[UIColor colorWithRed:.45 green:.3 blue:.15 alpha:1]];
		[taskStatusLabel setBackgroundColor:[UIColor clearColor]];
		[taskStatusLabel setText:NSLocalizedString(@"Status:", @"")];
		[taskStatusLabel setFont:fontDescr];
		taskStatusLabel.numberOfLines = 1;
		taskStatusLabel.shadowColor = [UIColor colorWithWhite:0.8 alpha:1.];
		taskStatusLabel.shadowOffset = CGSizeMake(0,1);
		CGSize sz = [[NSString stringWithString:NSLocalizedString(@"Status:", @"")] sizeWithFont:fontDescr];
		
		UIFont *fontStatus = [UIFont boldSystemFontOfSize:12];
		taskStatus = [[UILabel alloc] initWithFrame:CGRectMake(80 + sz.width + 10, 40, 180 - sz.width - 10, 20)];
		[taskStatus setTextColor:[UIColor colorWithRed:.45 green:.3 blue:.15 alpha:1]];
		[taskStatus setBackgroundColor:[UIColor clearColor]];
		[taskStatus setFont:fontStatus];
		taskStatus.numberOfLines = 1;
		taskStatus.shadowColor = [UIColor colorWithWhite:0.8 alpha:1.];
		taskStatus.shadowOffset = CGSizeMake(0,1);
		
		[self.contentView addSubview:taskName];
		[self.contentView addSubview:taskDescription];
		[self.contentView addSubview:taskStatusLabel];
		[self.contentView addSubview:taskStatus];
		
		status = ATTaskTableCellStatusIdle;
		isProgressShown = NO;
		isIndicatorShown = NO;
		
		indicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
		
		CGRect r = indicator.frame;
		r.origin.x = 320 - r.size.width - 10;
		r.origin.y = 40 - r.size.height / 2;
		indicator.frame = r;
		
		progress = [[UIProgressView alloc] initWithFrame:CGRectMake(80, 63, 200, 16)];
		[progress setProgress:0.0];
		
		UIImage *  im = [UIImage imageNamed:@"ATTask_Download.png"];
		iconView = [[UIImageView alloc] initWithImage:im];
		
		[self.contentView addSubview:iconView];
		
		self.selectionStyle = UITableViewCellSelectionStyleNone;
		
		
	}
	return self;
}

- (NSString*)description
{
	return [NSString stringWithFormat:@"<ATTaskTableViewCell: 0x%x  title=%@ desc=%@ progress=%f>", self, taskName.text, taskDescription.text, progress.progress];
}

- (void) setType:(ATTaskTableCellTypes)type
{
	if(type == ATTaskTableCellDownload || type == ATTaskTableCellInstall)
		[iconView setImage:[UIImage imageNamed:@"ATTask_Download.png"]];
	else
		[iconView setImage:[UIImage imageNamed:@"ATTask_Refresh.png"]];
}


- (void) setTitle:(NSString*)title
{
	[taskName setText:title];
}


- (void) setDescription:(NSString*)descr
{
	[taskDescription setText:descr];
	//[taskDescription setNeedsDisplay];
}

- (void) setStatus:(ATTaskTableCellStatus)st
{
	if (status == ATTaskTableCellStatusDone)
		return;
	status = st;
	if (status == ATTaskTableCellStatusActive && !isIndicatorShown)
	{
		// shows indicator
		[self.contentView addSubview:indicator];
		[indicator startAnimating];
		isIndicatorShown = YES;
	}
	else if (status != ATTaskTableCellStatusActive && isIndicatorShown)
	{
		isIndicatorShown = NO;
		[indicator removeFromSuperview];
		[indicator stopAnimating];
	}
	
	[indicator setNeedsDisplay];
	
	switch(status)
	{
		case ATTaskTableCellStatusIdle:
			[taskStatus setTextColor:[UIColor colorWithRed:.45 green:.3 blue:.15 alpha:1]];
			[taskStatus setText:NSLocalizedString(@"Idle", @"")];
			break;
		case ATTaskTableCellStatusFail:
			[taskStatus setTextColor:[UIColor colorWithRed:.9 green:.3 blue:.15 alpha:1]];
			[taskStatus setText:NSLocalizedString(@"Failed", @"")];
			break;
		case ATTaskTableCellStatusActive:
			[taskStatus setTextColor:[UIColor colorWithRed:.45 green:.3 blue:.15 alpha:1]];
			[taskStatus setText:NSLocalizedString(@"Active", @"")];
			break;
		case ATTaskTableCellStatusDone:
			[taskStatus setTextColor:[UIColor colorWithRed:.15 green:.45 blue:.15 alpha:1]];
			[taskStatus setText:NSLocalizedString(@"Done", @"")];
			[self setShowProgress:NO];
			break;
/*		case ATTaskTableCellStatusPause:
			[taskStatus setTextColor:[UIColor colorWithRed:.15 green:.3 blue:.65 alpha:1]];
			[taskStatus setText:@"Pause"];
			break;
		case ATTaskTableCellStatusStopByUser:
			[taskStatus setTextColor:[UIColor colorWithRed:.9 green:.3 blue:.15 alpha:1]];
			[taskStatus setText:@"Stop by user"];
			break; */
		default:
			break;
	}
	
	[taskStatus setNeedsDisplay];
}

- (void) _didEndHideIndicatorAnimation:(id)sender
{
	[indicator removeFromSuperview];
	[indicator stopAnimating];
}

- (void) setShowProgress:(bool)show
{
	if(show == isProgressShown)
		return;
	
	isProgressShown = show;
	if(isProgressShown)
	{
		[self.contentView addSubview:progress];
		/*
		progress.alpha = 0;
		[self.contentView addSubview:progress];
		[UIView beginAnimations:nil context:nil];
		[UIView setAnimationDuration:.3];
		progress.alpha = 1.0;
		[UIView commitAnimations];
		isProgressShown = YES;
		*/
		
	}
	else
	{
		/*
		[UIView beginAnimations:nil context:nil];
		[UIView setAnimationDuration:.3f];
		[UIView setAnimationDelegate:self];
		[UIView setAnimationDidStopSelector:@selector(_didEndHideProgressAnimation:)];
		progress.alpha = 0.0f;
		[UIView commitAnimations];
		isProgressShown = NO;
		*/
		[progress removeFromSuperview];
	}
}

- (void) _didEndHideProgressAnimation:(id)sender
{
	[progress removeFromSuperview];
}

- (void) setProgress:(float)pr
{
	if(!isProgressShown)
		return;
	progress.progress = pr;
	//[progress setNeedsDisplay];
}



- (void)dealloc {
	[taskName release];
	[taskDescription release];
	[taskStatus release];
	[taskStatusLabel release];
	[progress release];
	[indicator release];
	[super dealloc];
}


@end
