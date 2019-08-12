//
//  ATCategoriesCell.m
//  Installer
//
//  Created by DigitalStealth on 17.07.08.
//  Copyright 2008 DIGITAL STEALTH DESIGN GROUP. All rights reserved.
//

#import "ATCategoriesCell.h"

//static UIImage* backImage = nil;

static UIImage* gCategoryIcon_Installed = nil;
static UIImage* gCategoryIcon_Updated = nil;
static UIImage* gCategoryIcon_Plain = nil;

@implementation ATCategoriesCell

- (id)initWithFrame:(CGRect)frame reuseIdentifier:(NSString *)reuseIdentifier categoriesType:(int)type{
	if (self = [super initWithFrame:frame reuseIdentifier:reuseIdentifier]) {
		// Initialization code

		[self setCategoriesType:type];
		
		/*if (!backImage)
			backImage = [[UIImage imageNamed:@"ATCatBackground.png"] retain];
		
		UIImageView* backShadowImageView = [[UIImageView alloc] initWithImage:backImage];
		self.backgroundView = backShadowImageView;
		[backShadowImageView release];
		*/
		
		text = nil;
		textViewer = nil;
		self.textColor = [UIColor blackColor];
	}
	
	return self;
}

- (void) setCategoriesType:(int)type
{
	if (!gCategoryIcon_Plain)
	{
		gCategoryIcon_Plain = [[UIImage imageNamed:@"ATCAT_Other.png"] retain];
		gCategoryIcon_Updated = [[UIImage imageNamed:@"ATCAT_Updated.png"] retain];
		gCategoryIcon_Installed = [[UIImage imageNamed:@"ATCAT_Installed.png"] retain];
	}
	
	switch(type)
	{
		case ATCAtegoriesType_AllPackages:
			self.image = gCategoryIcon_Plain;
			break;
			
		case ATCategoriesTYPE_InstalledPackages:
			self.image = gCategoryIcon_Installed;
			break;
			
		case ATCategoriesTYPE_UpdatedPackages:
			self.image = gCategoryIcon_Updated;
			break;
			
		case ATCategoriesTYPE_RecentPackages:
			self.image = gCategoryIcon_Updated;
			break;
			
		case ATCategoriesTYPE_OtherCategories:
			self.image = gCategoryIcon_Plain;
			break;
			
		default:
			break;
	}
}

- (void) setText:(NSString*)t
{
	if(text != nil)
		[text release];

	text = [t retain];

	[self _reconcileViews];
}

- (NSString*)text
{
	return text;
}

- (void)setPackageCount:(NSUInteger)count
{
	packageCount = count;
	
	[self _reconcileViews];
}

- (NSUInteger)packageCount
{
	return packageCount;
}

- (void)_reconcileViews
{
	if(textViewer == nil)
	{
		textViewer = [[UILabel alloc] initWithFrame:CGRectMake(60, 0, 205, 20)];
		UIFont *font = [UIFont boldSystemFontOfSize:[UIFont systemFontSize]];
		[textViewer setFont:font];
		[textViewer setBackgroundColor:[UIColor colorWithRed:.85 green:.85 blue:.85 alpha:1]];
		textViewer.shadowColor = [UIColor colorWithWhite:0.8 alpha:1.];
		textViewer.shadowOffset = CGSizeMake(0,1);
		[self.contentView addSubview:textViewer];
	}
			
	[textViewer setText:text];
	
	if (subtitle == nil)
	{
		subtitle = [[UILabel alloc] initWithFrame:CGRectMake(60, 20, 205, 12)];
		UIFont *font = [UIFont systemFontOfSize:[UIFont smallSystemFontSize]];
		[subtitle setFont:font];
		[subtitle setBackgroundColor:[UIColor colorWithRed:.85 green:.85 blue:.85 alpha:1]];
		subtitle.textColor = [UIColor darkGrayColor];
		subtitle.shadowColor = [UIColor colorWithWhite:0.8 alpha:1.];
		subtitle.shadowOffset = CGSizeMake(0,1);
		
		[self.contentView addSubview:subtitle];
	}
	
	textViewer.backgroundColor = [UIColor clearColor];
	subtitle.backgroundColor = [UIColor clearColor];

	if (packageCount)
	{
		subtitle.text = [NSString stringWithFormat:(packageCount > 1 ? NSLocalizedString(@"%u total packages", @"") : NSLocalizedString(@"%u package", @"")), packageCount];
		
		textViewer.frame = CGRectMake(60, 4, 205, 20);
		subtitle.frame = CGRectMake(60, 24, 205, 12);
	}
	else
	{
		textViewer.frame = CGRectMake(60, 4, 205, 32);
		subtitle.frame = CGRectMake(60, 28, 205, 0);
		subtitle.text = @"";
	}
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated {

	if (selected)
	{
		[textViewer setTextColor:[UIColor whiteColor]];
		//textViewer.backgroundColor = [UIColor clearColor];
		//subtitle.backgroundColor = [UIColor clearColor];

	}
	else
	{
		[textViewer setTextColor:[UIColor blackColor]];
		//textViewer.backgroundColor = bg;
		//subtitle.backgroundColor = bg;
	}
		
	[super setSelected:selected animated:animated];
}

- (void)setOdd:(BOOL)isOdd
{
	[super setOdd:isOdd];
	
	//textViewer.backgroundColor = bg;
	//subtitle.backgroundColor = bg;
}

/*
- (void) setNeedsDisplay
{
	NSArray *subviews = [self.contentView subviews];
	
	for(int i = 0; i < [subviews count]; i++)
		[[subviews objectAtIndex:i] setBackgroundColor:[UIColor clearColor]];
	[super setNeedsDisplay];
}
*/


- (void)dealloc {
	if(text != nil)
		[text release];
	if(textViewer != nil)
		[textViewer release];
	[subtitle release];
	[super dealloc];
}


@end
