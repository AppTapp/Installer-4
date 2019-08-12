#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

#import "ATInstaller.h"
#import "ATSource.h"
#import "ATTableViewCell.h"

@interface ATSourceTableViewCell : ATTableViewCell {
	UILabel *sourceNameView;
	UILabel *sourceDescriptionView;
	UIImageView *iconView;

	ATSource* source;
}

@property (retain) ATSource* source;

- (id)initWithFrame:(CGRect)frame reuseIdentifier:(NSString *)reuseIdentifier source:(ATSource*)s;
- (void)setSource:(ATSource*)source;
@end
