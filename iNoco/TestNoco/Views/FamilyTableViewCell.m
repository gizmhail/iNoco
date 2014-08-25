//
//  FamilyTableViewCell.m
//  iNoco
//
//  Created by Sébastien POIVRE on 25/08/2014.
//  Copyright (c) 2014 Sébastien Poivre. All rights reserved.
//

#import "FamilyTableViewCell.h"

@implementation FamilyTableViewCell

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        // Initialization code
    }
    return self;
}

- (void)awakeFromNib{
    UIView* backgroundView = [self viewWithTag:300];
    
    backgroundView.layer.borderColor = [UIColor lightGrayColor].CGColor;
    backgroundView.layer.borderWidth = 1;
    
    [backgroundView.layer setShadowColor:[UIColor lightGrayColor].CGColor];
    [backgroundView.layer setShadowOpacity:0.5];
    [backgroundView.layer setShadowRadius:0.2];
    [backgroundView.layer setShadowOffset:CGSizeMake(1, 1)];
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated
{
    [super setSelected:selected animated:animated];

    // Configure the view for the selected state
}

@end
