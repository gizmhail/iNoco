//
//  RecentShowViewController.h
//  TestNoco
//
//  Created by Sébastien POIVRE on 21/06/2014.
//  Copyright (c) 2014 Sébastien Poivre. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "RecentShowViewController.h"
#import "ConnectionViewController.h"
#import "NLTAPI.h"
#import "ShowCollectionViewCell.h"

@interface RecentShowViewController : UIViewController <UICollectionViewDataSource,UICollectionViewDelegate,ConnectionViewControllerDelegate,UISearchBarDelegate,UIAlertViewDelegate>{
    int maxShows;
}
@property (assign,nonatomic) BOOL initialAuthentCheckDone;
@property (retain, nonatomic) NSMutableDictionary* resultByPage;
@property (retain, nonatomic) NSMutableDictionary* filteredResultByPage;
@property (weak, nonatomic) IBOutlet UICollectionView *collectionView;
@property (retain, nonatomic) NSString* filter;
@property (retain, nonatomic) NLTFamily* family;
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *activity;
@property (weak, nonatomic) IBOutlet UISearchBar *searchBar;
@property (assign,nonatomic) BOOL noNetworkForAuth;
@property (weak, nonatomic) IBOutlet UIView *filterView;
@property (weak, nonatomic) IBOutlet UISegmentedControl *watchSegmentedControl;
@property (weak, nonatomic) IBOutlet UIView *filterBackground;
@property (retain,nonatomic)UIAlertView* errorAlert;
@property (retain,nonatomic)UIAlertView* quotaAlert;

- (id)resultAtIndex:(long)index;
- (NLTShow*)showAtIndex:(long)showIndex;
- (NSIndexPath*)pageAndIndexInPageFor:(long)showIndex;
- (void)loadResultAtIndex:(int)resultIndex;
- (void)resetResult;
- (void)removeResultAtIndex:(long)index;
- (void)loadShowCell:(ShowCollectionViewCell*)cell withShow:(NLTShow*)show;
- (void)launchFullsearchForFilter;
- (BOOL)checkErrorForQuotaLimit:(NSError*)error;
- (IBAction)watchSegmentedControlChange:(id)sender;
@end
