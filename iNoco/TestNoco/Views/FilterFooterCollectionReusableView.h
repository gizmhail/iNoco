//
//  FilterFooterCollectionReusableView.h
//  iNoco
//
//  Created by Sébastien POIVRE on 25/07/2014.
//  Copyright (c) 2014 Sébastien Poivre. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "RecentShowViewController.h"

@interface FilterFooterCollectionReusableView : UICollectionReusableView
@property (assign,nonatomic) RecentShowViewController* delegate;
@end
