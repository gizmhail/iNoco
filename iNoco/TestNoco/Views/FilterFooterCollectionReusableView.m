//
//  FilterFooterCollectionReusableView.m
//  iNoco
//
//  Created by Sébastien POIVRE on 25/07/2014.
//  Copyright (c) 2014 Sébastien Poivre. All rights reserved.
//

#import "FilterFooterCollectionReusableView.h"

@implementation FilterFooterCollectionReusableView

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [self configureAction];
    }
    return self;
}

-(id)initWithCoder:(NSCoder *)aDecoder{
    self = [super initWithCoder:aDecoder];
    if (self) {
        [self configureAction];
    }
    return self;
}

- (void)configureAction{
    UIButton* button = (UIButton*)[self viewWithTag:1000];
    [button addTarget:self.delegate action:@selector(launchFullsearchForFilter) forControlEvents:UIControlEventTouchUpInside];
}
/*
// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect
{
    // Drawing code
}
*/

@end
