//
//  WatchListHeaderReusableView.m
//  TestNoco
//
//  Created by Sébastien POIVRE on 05/07/2014.
//  Copyright (c) 2014 Sébastien Poivre. All rights reserved.
//

#import "WatchListHeaderReusableView.h"

@interface WatchListHeaderReusableView ()
@property(retain,nonatomic) CAGradientLayer* gradientLayer;

@end
@implementation WatchListHeaderReusableView

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [self initializeEffects];
    }
    return self;
}

-(id)initWithCoder:(NSCoder *)aDecoder{
    self = [super initWithCoder:aDecoder];
    if (self) {
        [self initializeEffects];
    }
    return self;
}

- (void)initializeEffects{
    self.gradientLayer = [CAGradientLayer layer];
    self.gradientLayer.frame = self.bounds;
    UIColor *firstColor = [UIColor grayColor];
    UIColor *secondColor = [UIColor lightGrayColor] ;
    self.gradientLayer.colors = [NSArray arrayWithObjects:(id)firstColor.CGColor, (id)secondColor.CGColor, nil];
    [self.layer insertSublayer:self.gradientLayer atIndex:0];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    self.gradientLayer.frame = self.bounds;
}

@end
