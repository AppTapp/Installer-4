//
//  ATIconView.m
//  Installer
//
//  Created by DigitalStealth on 19.07.08.
//  Copyright 2008 DIGITAL STEALTH DESIGN GROUP. All rights reserved.
//

#import "ATIconView.h"

static UIImage* gDefaultPackageIcon = nil;
static UIImage* gIconClippingMask = nil;
static UIImage* gIconTrustedImage = nil;
static UIImage* gIconNewImage = nil;
static UIImage* gIconStopImage = nil;

@implementation ATIconView

@synthesize hasErrors;
@synthesize drawShadow;

- (id)initWithFrame:(CGRect)frame {
	if (self = [super initWithFrame:frame]) {
		// Initialization code
		
		icon = nil;
		iconMirror = nil;
		[self setBackgroundColor:[UIColor clearColor]];
		isTrusted = NO;
		isNew = NO;
		hasErrors = NO;
	}
	return self;
}

- (void)dealloc
{
	[icon release];
	[iconMirror release];
	
	[super dealloc];
}


- (void)drawRect:(CGRect)rect {
	// Drawing code
	if(icon == nil)
	{
		if (!gDefaultPackageIcon)
			gDefaultPackageIcon = [[UIImage imageNamed:@"ATPack_Package.png"] retain];
		//[gDefaultPackageIcon drawInRect:CGRectMake(5,0,80,80)];
		[gDefaultPackageIcon drawInRect:CGRectMake(10,10,60,60)];

	}
	else
	{
		if (drawShadow)
		{
			if(iconMirror == nil)
			{
				CGImageRef iconRef = [icon CGImage];
							
				CGContextRef ref = CGBitmapContextCreate(NULL, 
														 CGImageGetWidth(iconRef), 
														 CGImageGetHeight(iconRef), 
														 CGImageGetBitsPerComponent(iconRef), 
														 CGImageGetBytesPerRow(iconRef), 
														 CGImageGetColorSpace(iconRef), 
														 kCGImageAlphaPremultipliedFirst);//CGImageGetBitmapInfo(iconRef));
				
				
				CGAffineTransform transScale = CGAffineTransformMakeScale(1.0, -1.0);
				CGContextConcatCTM(ref, transScale);
				//CGContextScaleCTM(ref, -1.0, 1.0);
				CGContextDrawImage(ref, CGRectMake(0, -60, 60, 60), iconRef);
				
				CGImageRef scaledImage = CGBitmapContextCreateImage(ref);
				
				iconMirror = [[UIImage alloc] initWithCGImage:scaledImage];
				CGContextRelease(ref);
				CGImageRelease(scaledImage);
			}
			
			// drawing a shadow
			CGContextRef cgc = UIGraphicsGetCurrentContext();
			CGContextSaveGState(cgc);
			CGContextSetLineWidth(cgc, 2);
			float blackColor[] = {0, 0, 0, 1};
			CGContextSetStrokeColor(cgc, blackColor);

			CGRect r = [self frame];
			CGContextClipToRect(cgc, CGRectMake(10, 60, 60, r.size.height - 60 - 1));

			if (!gIconClippingMask)
				gIconClippingMask = [[UIImage imageNamed:@"IconClipingMask.png"] retain];
				
			UIImage *mask = gIconClippingMask;
			CGContextClipToMask(cgc, CGRectMake(10, 60, 60, 60), [mask CGImage]);

			[iconMirror drawInRect:CGRectMake(10, 67, 60, 60) blendMode:kCGBlendModeNormal alpha:0.4];
			
			CGContextRestoreGState(cgc);
			[icon drawInRect:CGRectMake(10, 10, 60, 60) blendMode:kCGBlendModeNormal alpha:1.0];
			
			CGContextSaveGState(cgc);
			CGContextClipToRect(cgc, CGRectMake(10, 40, 60, r.size.height - 40 - 1));
			CGContextRestoreGState(cgc);
		}
		else
		{
			CGSize sz = icon.size;
			
			sz.width = floorf(sz.width);
			sz.height = floorf(sz.height);
			
			if (sz.width > 60 || sz.height > 60)
			{
				float mult = .0;
				
				if (sz.width > sz.height)
					mult = 60/sz.width;
				else
					mult = 60/sz.height;
				
				sz.width *= mult;
				sz.height *= mult;
				
				
				rect.size = sz;
				rect.origin.x = 10;
				rect.origin.y = 10;
			}
			else
			{
				rect.size = sz;
				rect.origin.x = floorf(40 - (sz.width / 2));
				rect.origin.y = floorf(40 - (sz.height / 2));
			}
				
			[icon drawInRect:rect blendMode:kCGBlendModeNormal alpha:1.];
		}
	}
	
	// drawing icons of new and trusted
	if(isTrusted)
	{
		if (!gIconTrustedImage)
			gIconTrustedImage = [[UIImage imageNamed:@"ATTrustedicon.png"] retain];
		[gIconTrustedImage drawInRect:CGRectMake(33, 50, 40, 39) blendMode:kCGBlendModeNormal alpha:1];
	}
	
	
	if(isNew)
	{
		if (!gIconNewImage)
			gIconNewImage = [[UIImage imageNamed:@"ATNewIcon.png"] retain];
		[gIconNewImage drawInRect:CGRectMake(55, 5, 24, 24) blendMode:kCGBlendModeNormal alpha:1];
	}
		
	if (hasErrors)
	{
		if (!gIconStopImage)
			gIconStopImage = [[UIImage imageNamed:@"ATStopIcon.png"] retain];
		[gIconStopImage drawInRect:CGRectMake(55, 5, 24, 24) blendMode:kCGBlendModeNormal alpha:1];
	}
}


-(void) setIcon:(UIImage*) iconSource
{
	[icon release];
	icon = [iconSource retain];
	
	[iconMirror release];
	iconMirror = nil;
	
	[self setNeedsDisplay];
}

- (void)setImage:(UIImage*)ico
{
	[self setIcon:ico];
}

- (void) setTrusted:(bool)isT
{
	if(isT == isTrusted)
		return;
	isTrusted = isT;
	[self setNeedsDisplay];
}


- (void) setNew:(bool) isN
{
	if(isN == isNew)
		return;
	isNew = isN;
	[self setNeedsDisplay];
}


@end
