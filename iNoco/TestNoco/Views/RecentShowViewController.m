//
//  RecentShowViewController.m
//  TestNoco
//
//  Created by Sébastien POIVRE on 21/06/2014.
//  Copyright (c) 2014 Sébastien Poivre. All rights reserved.
//

#import "RecentShowViewController.h"
#import <QuartzCore/QuartzCore.h>
#import "UIImageView+WebCache.h"
#import <MediaPlayer/MediaPlayer.h>
#import "ShowViewController.h"
#import "UIView+Toast.h"
#import "FavoriteProgramManager.h"
#import "FilterFooterCollectionReusableView.h"
#import "SearchViewController.h"
#import "ConnectionViewController.h"

@interface RecentShowViewController (){
    BOOL emptyPageFound;
    int pendingPageCalls;
    int firstEmptyPageFound;
}
@property (retain,nonatomic)UIButton* favoriteFamilly;
@property (retain,nonatomic)UIRefreshControl* refreshControl;
@end

@implementation RecentShowViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self resetResult];
    [self refreshControlSetup];
}

- (void)refreshControlSetup{
    self.refreshControl = [[UIRefreshControl alloc] init];
    //self.refreshControl.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.6];
    //self.refreshControl.frame = CGRectMake(0, 0, self.collectionView.frame.size.width, 2);
    
    NSMutableAttributedString* attr = [[NSMutableAttributedString alloc] initWithString:@"Tirer pour rafraichir"];
    /*
    [attr addAttribute:NSBackgroundColorAttributeName value:[THEME_COLOR colorWithAlphaComponent:0.9] range:[attr.string rangeOfString:attr.string ] ];
    [attr addAttribute:NSForegroundColorAttributeName value:[UIColor whiteColor] range:[attr.string rangeOfString:attr.string ] ];
    */
    
    self.refreshControl.attributedTitle = attr;

    [self.refreshControl addTarget:self action:@selector(forceRefreshResult) forControlEvents:UIControlEventValueChanged];
    [self.collectionView addSubview:self.refreshControl];
    
    self.collectionView.alwaysBounceVertical = YES;
}

-(void)viewWillAppear:(BOOL)animated{
    if([self.navigationController.viewControllers indexOfObject:self]==0){
        //Root view
        self.navigationController.navigationBarHidden = TRUE;
    }else{
        self.navigationController.navigationBarHidden = FALSE;
        self.searchBar.hidden = TRUE;
    }
    
    if(self.family || (ALWAYS_DISPLAY_READFILTER_IN_RECENT_SHOWS && [self isMemberOfClass:[RecentShowViewController class]]) ){
        //We force display of filter viewx in family mode
        if(self.filterView.hidden){
            self.filterView.hidden = FALSE;
        }
    }
    
    if(self.family){
        self.title = self.family.family_TT;
        if(!self.navigationItem.rightBarButtonItem){
            self.favoriteFamilly = [UIButton buttonWithType:UIButtonTypeCustom];
            self.favoriteFamilly.accessibilityLabel = @"programme favoris";
            self.favoriteFamilly.accessibilityHint = @"cliquer pour mettre ou enlever le programme de cette émission dans les programmes favoris";
            self.favoriteFamilly.frame = CGRectMake(0, 0, 30, 30);
            [self.favoriteFamilly setImage:[UIImage imageNamed:@"heart_off"] forState:UIControlStateNormal];
            [self.favoriteFamilly setImage:[UIImage imageNamed:@"heart_on"] forState:UIControlStateSelected];
            [self.favoriteFamilly addTarget:self action:@selector(favoriteFamillyClick:) forControlEvents:UIControlEventTouchUpInside];
            self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:self.favoriteFamilly];
        }
        self.favoriteFamilly.selected = [[FavoriteProgramManager sharedInstance] isFavoriteForFamilyKey:self.family.family_key withPartnerKey:self.family.partner_key];
    }
    [self fixNavigationBarRelativePosition];
    [super viewWillAppear:animated];
}

-(void)viewWillDisappear:(BOOL)animated{
    self.navigationItem.rightBarButtonItem = nil;
    [super viewWillDisappear:animated];
}

- (IBAction)favoriteFamillyClick:(id)sender {
    if(self.family){
        self.favoriteFamilly.selected = !self.favoriteFamilly.selected;
        [[FavoriteProgramManager sharedInstance] setFavorite:self.favoriteFamilly.selected forFamilyKey:self.family.family_key withPartnerKey:self.family.partner_key];
        if(self.favoriteFamilly.selected){
            [self.tabBarController.view makeToast:[NSString stringWithFormat:@"Programme %@ ajouté aux favoris", self.family.family_TT] duration:2 position:@"bottom"];
        }else{
            [self.tabBarController.view makeToast:[NSString stringWithFormat:@"Programme %@ retiré des favoris", self.family.family_TT] duration:2 position:@"bottom"];
        }
    }
}

-(void)viewDidAppear:(BOOL)animated{
    self.initialAuthentCheckDone = FALSE;
    if(!self.noNetworkForAuth){
        [self showLoadingActivity];
        [self refreshResult];
    }else{
        //Back from auth try, with lacking network: we avoid, once, to try to reconnect
        self.noNetworkForAuth = FALSE;
    }
    [super viewDidAppear:animated];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

- (BOOL)checkErrorForQuotaLimit:(NSError*)error{
    BOOL quotaError = false;
    if(error && [error.domain compare:@"NLTAPIDomain"]==NSOrderedSame && error.code == NLTAPI_NOCO_ERROR){
        if([error.userInfo objectForKey:@"code"] && [(NSString*)[error.userInfo objectForKey:@"code"] compare:@"TOO_MANY_REQUESTS"]==NSOrderedSame){
            quotaError = TRUE;
            if(![self.quotaAlert isVisible]){
                self.quotaAlert = [[UIAlertView alloc] initWithTitle:@"Erreur" message:@"Trop de connections simultanées faites à Noco : veuillez attendre quelques instants (une minute environ) avant de refaire un appel" delegate:nil cancelButtonTitle:@"Ok" otherButtonTitles:nil];
                [self.quotaAlert show];
            }
        }
    }
    return quotaError;
}

- (IBAction)watchSegmentedControlChange:(id)sender {
    [self refreshResult];
    if(self.family){
        //Filter is not displayed
        [self.collectionView reloadData];
    }else{
        [self searchBarSearchButtonClicked:self.searchBar];
    }
}

#pragma mark Activity

- (void)showLoadingActivity{
    [self.view makeToastActivity];
}

- (void)hideLoadingActivity{
    [self.view hideToastActivity];
}


#pragma mark ConnectionViewControllerDelegate

- (void) stopRefreshControl{
    [self.refreshControl endRefreshing];
    /*
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NSMutableAttributedString* attr = [[NSMutableAttributedString alloc] initWithString:@"Tirer pour rafraichir"];
        [attr addAttribute:NSBackgroundColorAttributeName value:[THEME_COLOR colorWithAlphaComponent:0.9] range:[attr.string rangeOfString:attr.string ] ];
        [attr addAttribute:NSForegroundColorAttributeName value:[UIColor whiteColor] range:[attr.string rangeOfString:attr.string ] ];
        self.refreshControl.attributedTitle = attr;
    });
     */
}

- (void) forceRefreshResult{
    /*
    NSMutableAttributedString* attr = [[NSMutableAttributedString alloc] initWithString:@"Tirer pour rafraichir"];
    self.refreshControl.attributedTitle = attr;
    */
    
    maxShows = -1;
    [[NLTAPI sharedInstance] invalidateCacheWithPrefix:@"shows"];
    [self refreshResult];

}

- (void)refreshResult{
    [self resetResult];
    [self.collectionView reloadData];
    UIAccessibilityPostNotification(UIAccessibilityLayoutChangedNotification, self.collectionView);
    __weak RecentShowViewController* weakSelf = self;
    [[NLTOAuth sharedInstance] isAuthenticatedAfterRefreshTokenUse:^(BOOL authenticated, NSError* error) {
#warning TODO Handle offline properly (add Reachability, ...)
        self.initialAuthentCheckDone = TRUE;
        if(!authenticated){
            [weakSelf hideLoadingActivity];
            if([error.domain compare:NSURLErrorDomain]==NSOrderedSame && error.code == -1009){
                [weakSelf stopRefreshControl];
                [[[UIAlertView alloc] initWithTitle:@"Erreur" message:@"Impossible de se connecter. Veuillez vérifier votre connection." delegate:self   cancelButtonTitle:@"Ok" otherButtonTitles:nil] show];
            }else{
                //Segueue should not occur during viewWilll/DidAppear
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    [weakSelf performSegueWithIdentifier:@"NotConnectedSegue" sender:self];
                });
                [weakSelf stopRefreshControl];
            }
        }else{
            [weakSelf connectedToNoco];
            //Fetch partners logo
            [[NLTAPI sharedInstance] partnersWithResultBlock:^(id result, NSError *error) {
                [self.collectionView reloadData];
                [self checkErrorForQuotaLimit:error];
            } withKey:self];
        }
        UIAccessibilityPostNotification(UIAccessibilityLayoutChangedNotification, self.collectionView);
    }];
}

- (void)resetResult{
    maxShows = -1;
    self.resultByPage = [NSMutableDictionary dictionary];
    self.filteredResultByPage = [NSMutableDictionary dictionary];
    emptyPageFound = FALSE;
}

- (void)connectedToNoco{
    [self loadResultAtIndex:0];
}

- (void)noNetwordForAuth{
    self.noNetworkForAuth = TRUE;
}

- (long)greatestFetchedPage{
    return [[[self.resultByPage allKeys] valueForKeyPath:@"@max.intValue"] integerValue];
}

- (void)loadResultAtIndex:(long)resultIndex{
    NSIndexPath* indexPath = [self pageAndIndexInPageFor:resultIndex];
    int page = (int) indexPath.section;
    __weak RecentShowViewController* weakSelf = self;
    if(![self.resultByPage objectForKey:[NSNumber numberWithInt:page]]){
        [[NLTOAuth sharedInstance]isAuthenticatedAfterRefreshTokenUse:^(BOOL authenticated, NSError* error) {
            if(authenticated){
                if(weakSelf.filter && page > [weakSelf greatestFetchedPage]){
                    //If filtering, we don't download additionnal pages (unless some pages were missing, skipped due to high speed scrolling)
                    [weakSelf hideLoadingActivity];
                }else{
                    [weakSelf showLoadingActivity];
                    pendingPageCalls++;
#ifdef DEBUG_SHOWLIST_MAXSHOW
                    NSLog(@"pendingPageCalls++: %i", pendingPageCalls);
#endif
                    [weakSelf loadResultsAtPage:page withResultBlock:^(id result, NSError *error) {
                        pendingPageCalls--;
#ifdef DEBUG_SHOWLIST_MAXSHOW
                        NSLog(@"pendingPageCalls--: %i", pendingPageCalls);
#endif
                        [weakSelf hideLoadingActivity];
                        [weakSelf stopRefreshControl];
                        if(error){
#ifdef DEBUG_SHOWLIST_MAXSHOW
                            [weakSelf.tabBarController.view makeToast:[NSString stringWithFormat:@"Setting maxShows due to error %@", [error description]] duration:10 position:@"bottom"];
                            NSLog(@"Error: %@", error);
#endif
                            BOOL quotaError = [self checkErrorForQuotaLimit:error];
                            maxShows = [self entriesCount];
                            if(!self.errorAlert&&!quotaError){
                                self.errorAlert = [[UIAlertView alloc] initWithTitle:@"Erreur" message:@"Impossible de se connecter. Veuillez vérifier votre connection." delegate:self   cancelButtonTitle:@"Ok" otherButtonTitles:nil];
                                [self.errorAlert show];
                            }
                            [weakSelf.collectionView reloadData];
                        }else{
                            [weakSelf insertPageResult:page withResult:result withError:error];
                        }
                        if(emptyPageFound){
                            if(pendingPageCalls <= 0){
                                maxShows = [self entriesCount];
                                [weakSelf.collectionView reloadData];
#ifdef DEBUG_SHOWLIST_MAXSHOW
                                [weakSelf.tabBarController.view makeToast:[NSString stringWithFormat:@"Setting maxShows %i due to empty page found at page %i (and no pending calls)", maxShows,firstEmptyPageFound] duration:10 position:@"bottom"];
#endif
                            }else{
#ifdef DEBUG
                                NSLog(@"Empty page found, but still %i calls pending", pendingPageCalls);
#endif
                            }
                        }
                    }];
                }
            }else{
#warning TODO Handle offline
                [weakSelf hideLoadingActivity];
                [weakSelf stopRefreshControl];
            }
        }];
    }else{
        [self hideLoadingActivity];
        [self stopRefreshControl];
    }
}

- (void)loadResultsAtPage:(int)page withResultBlock:(NLTCallResponseBlock)responseBlock{
    NSString* watchFilter = nil;
    if(self.watchSegmentedControl.selectedSegmentIndex == 1){
        watchFilter = NLTAPI_WATCHFILTER_READONLY;
    }
    if(self.watchSegmentedControl.selectedSegmentIndex == 2){
        watchFilter = NLTAPI_WATCHFILTER_UNREADONLY;
    }
    [[NLTAPI sharedInstance] showsAtPage:page withResultBlock:responseBlock withFamilyKey:self.family.family_key withWatchFilter:watchFilter withKey:self];

}

- (long)entriesCount{
    long entries = 0;
    NSDictionary* pageDictionary = self.resultByPage;
    if(self.filter){
        pageDictionary = self.filteredResultByPage;
    }
    
    NSNumber * maxPage = [[pageDictionary allKeys] valueForKeyPath:@"@max.intValue"];
    for (int i = 0; i<= [maxPage integerValue]; i++) {
        if([pageDictionary objectForKey:[NSNumber numberWithInt:i]]){
            entries += [[pageDictionary objectForKey:[NSNumber numberWithInt:i]] count];
        }else{
            entries += [[NLTAPI sharedInstance] resultsByPage];
        }
    }
    return entries;
}

- (void)insertPageResult:(int)page withResult:(id)result withError:(NSError*)error{
    if(result&&[result isKindOfClass:[NSArray class]]){
        if([(NSArray*)result count]<[[NLTAPI sharedInstance] resultsByPage]){
            //End of available shows (not a full page of results)
            if(!emptyPageFound){
                //For debug purposes
                firstEmptyPageFound = page;
            }
            emptyPageFound = TRUE;
        }
        BOOL newPage = true;
        if([self.resultByPage objectForKey:[NSNumber numberWithInt:page]]){
            newPage = false;
        }
        [self.resultByPage setObject:[NSMutableArray arrayWithArray:result] forKey:[NSNumber numberWithInt:page]];
        [self filterShowsAtPage:page];
        if(newPage){
            [self.collectionView reloadData];
            UIAccessibilityPostNotification(UIAccessibilityLayoutChangedNotification, self.collectionView);
        }
    }else{
        //TODO Handle error
        NSLog(@"Unexpected page result");
    }
}

- (NSIndexPath*)pageAndIndexInPageFor:(long)showIndex{
    long page = 0;
    long indexInPage = 0;
    NSDictionary* pageDictionary = self.resultByPage;
    if(self.filter){
        pageDictionary = self.filteredResultByPage;
    }
    long remainingIndex = showIndex;
    int currentPage = 0;
    while(remainingIndex >= 0){
        //Default page count if page not fetched
        long pageCount = (long)[[NLTAPI sharedInstance] resultsByPage];
        NSArray* resultsInPage = [pageDictionary objectForKey:[NSNumber numberWithInt:currentPage]];
        if(resultsInPage){
            pageCount = [resultsInPage count];
        }
        if(pageCount > remainingIndex){
            indexInPage = remainingIndex;
            page = currentPage;
            break;
        }else{
            remainingIndex -= pageCount;
            currentPage++;
        }
    }
    return [NSIndexPath indexPathForRow:indexInPage inSection:page];
}

- (NSMutableArray*)allContextShows{
    NSMutableArray* shows = [NSMutableArray array];
    NSDictionary* pageDictionary = self.resultByPage;
    if(self.filter){
        pageDictionary = self.filteredResultByPage;
    }
    for (NSArray* items in [pageDictionary allValues]) {
        [shows addObjectsFromArray:items];
    }
    return shows;
}

- (id)resultAtIndex:(long)index{
    NSIndexPath* indexPath = [self pageAndIndexInPageFor:index];
    long page = indexPath.section;
    long indexInPage = indexPath.row;
    //NSLog(@"%i : %i / %i",showIndex, page, indexInPage);
    id result = nil;
    NSDictionary* pageDictionary = self.resultByPage;
    if(self.filter){
        pageDictionary = self.filteredResultByPage;
    }
    NSArray* pageResults = [pageDictionary objectForKey:[NSNumber numberWithInt:(int)page]];
    if(pageResults){
        if([pageResults count]>indexInPage){
            result = [pageResults objectAtIndex:indexInPage];
            /*
             Remove if not needed
            //We try to fetch the same instance as the cached instance (if controller local cache is outdated, this avoid having 2 different instances)
            if([result isKindOfClass:[NLTShow class]]&&[[NLTAPI sharedInstance].showsById objectForKey:[NSNumber numberWithInt:[(NLTShow*)result id_show]]]){
                result = [[NLTAPI sharedInstance].showsById objectForKey:[NSNumber numberWithInt:[(NLTShow*)result id_show]]];
            }
            if([result isKindOfClass:[NLTFamily class]]&&[[NLTAPI sharedInstance].familiesById objectForKey:[NSNumber numberWithInt:[(NLTFamily*)result id_family]]]){
                result = [[NLTAPI sharedInstance].familiesById objectForKey:[NSNumber numberWithInt:[(NLTFamily*)result id_family]]];
            }
             */
        }else{
            NSLog(@"Index PB");
        }
    }
    return result;
}


- (void)removeResultAtIndex:(long)index{
    NSIndexPath* indexPath = [self pageAndIndexInPageFor:index];
    long page = indexPath.section;
    long indexInPage = indexPath.row;
    NSDictionary* pageDictionary = self.resultByPage;
    if(self.filter){
        pageDictionary = self.filteredResultByPage;
    }
    NSMutableArray* pageResults = [pageDictionary objectForKey:[NSNumber numberWithInt:(int)page]];
    if(pageResults){
        if([pageResults count]>indexInPage){
            [pageResults removeObjectAtIndex:indexInPage];
        }else{
            NSLog(@"Index PB");
        }
    }
}

- (NLTShow*)showAtIndex:(long)showIndex{
    NLTShow* show = [self resultAtIndex:showIndex];
    if(!show){
        //We want a bit to be sure the call call is still needed
        __weak RecentShowViewController* weakSelf = self;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            UICollectionViewCell* cell = [weakSelf.collectionView cellForItemAtIndexPath:[NSIndexPath indexPathForRow:showIndex inSection:0]];
            if([[weakSelf.collectionView visibleCells] containsObject:cell]){
                [weakSelf loadResultAtIndex:showIndex];
            }else{
                //Loading not needed anymore
                //NSLog(@"Loading not needed");
            }
        });
    }
    return show;
}

- (void)filterShowsWithString{
    int total = 0;
    int filtered = 0;
    if(self.filter){
        self.filteredResultByPage = [NSMutableDictionary dictionary];
        for (NSNumber* page in [self.resultByPage allKeys]) {
            [self filterShowsAtPage:[page longValue]];
            total += [[self.resultByPage objectForKey:page] count];
            filtered += [[self.filteredResultByPage objectForKey:page] count];
        }
    }
    NSLog(@"Filter : %i / %i",filtered, total);
}

- (void)filterShowsAtPage:(long)page{
    if(self.filter){
        NSArray* shows = [self.resultByPage objectForKey:[NSNumber numberWithInt:page]];
        if(shows){
            NSMutableArray* filteredShows = [NSMutableArray array];
            for (NLTShow* show in shows) {
                NSMutableArray* filteringFields = [NSMutableArray array];
                if(show.show_TT)[filteringFields addObject:show.show_TT];
                if(show.show_resume)[filteringFields addObject:show.show_resume];
                if(show.family_TT)[filteringFields addObject:show.family_TT];
                if(show.show_OT)[filteringFields addObject:show.show_OT];
                if(show.family_OT)[filteringFields addObject:show.family_OT];
                for (NSString* val in filteringFields) {
                    if([val isKindOfClass:[NSString class]]){
                        if([val rangeOfString:self.filter options:NSCaseInsensitiveSearch].location != NSNotFound){
                            [filteredShows addObject:show];
                            break;
                        }
                    }
                }
            }
            [self.filteredResultByPage setObject:filteredShows forKey:[NSNumber numberWithLong:page]];
        }
    }
}

- (void)launchFullsearchForFilter{
    if (self.filter != nil && [self.filter compare:@""] != NSOrderedSame) {
        [self.tabBarController setSelectedIndex:2];
        UINavigationController* searchNav = (UINavigationController*)[self.tabBarController.viewControllers objectAtIndex:2];
        [searchNav popToRootViewControllerAnimated:NO];
        SearchViewController* searchController = [[searchNav viewControllers] firstObject];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            searchController.search = self.filter;
            searchController.searchBar.text = self.filter;
            [searchController searchBarSearchButtonClicked:searchController.searchBar];
        });
    }

}

#pragma mark UIAlertviewDelegate

-(void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex{
    if(alertView==self.errorAlert){
        self.errorAlert = nil;
    }
}
#pragma mark UISearchbarDelegate



- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText{
}

- (void)searchBarCancelButtonClicked:(UISearchBar *) searchBar{
    searchBar.text = @"";
    [searchBar resignFirstResponder];
    self.filter = nil;
    self.filteredResultByPage = nil;
    [self.collectionView reloadData];
    UIAccessibilityPostNotification(UIAccessibilityLayoutChangedNotification, @"Filtrage");
    self.filterView.hidden = TRUE;
}


- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar{
    self.filter = searchBar.text;
    if([self.filter compare:@""]==NSOrderedSame){
        self.filter = nil;
    }
    [self filterShowsWithString];
    //[self.collectionView reloadItemsAtIndexPaths:[self.collectionView indexPathsForVisibleItems]];
    [self.collectionView reloadData];
    UIAccessibilityPostNotification(UIAccessibilityLayoutChangedNotification, @"Annulation du filtre");
    [searchBar resignFirstResponder];
    [[UISegmentedControl appearanceWhenContainedIn:[UISearchBar class], nil] setTintColor:searchBar.tintColor];
    if( ! ALWAYS_DISPLAY_READFILTER_IN_RECENT_SHOWS || ! [self isMemberOfClass:[RecentShowViewController class]] ){
        self.filterView.hidden = TRUE;
    }
}

- (BOOL)searchBarShouldBeginEditing:(UISearchBar *)searchBar {
    self.filterView.hidden = FALSE;
    return YES;
}

/*
- (BOOL)searchBarShouldEndEditing:(UISearchBar *)searchBar {
    [searchBar setScopeButtonTitles:@[]];
    searchBar.showsScopeBar = NO;
    [searchBar sizeToFit];
    [searchBar setShowsCancelButton:NO animated:YES];
    
    return YES;
}
 */

#pragma mark UICollectioViewDatasource

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section{
    if(!self.initialAuthentCheckDone){
        return 0;
    }
    if(self.filter){
        long maxPage = [self greatestFetchedPage];
        long page =  0 ;
        int total = 0;
        while(page <= maxPage){
            NSArray* filteredShowsInPage = [self.filteredResultByPage objectForKey:[NSNumber numberWithLong:page]];
            long pageCount = [[NLTAPI sharedInstance] resultsByPage];
            if(filteredShowsInPage){
                pageCount = [filteredShowsInPage count];
            }
            total += pageCount;
            page++;
        }
        return total;
    }else{
        if(maxShows == -1){
            //While we don't know the end
            return 2000;
        }
        return maxShows;
    }
}

- (void)loadShowCell:(ShowCollectionViewCell*)cell withShow:(NLTShow*)show{
    [cell loadShow:show];
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath{
    NLTShow* show = [self showAtIndex:indexPath.row];
    UICollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"ShowsCell" forIndexPath:indexPath];
    if([cell isKindOfClass:[ShowCollectionViewCell class]]){
        [self loadShowCell:(ShowCollectionViewCell*)cell withShow:show];
    }else{
        NSLog(@"PB with cell loading");
    }
    return cell;
}

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView{
    return 1;
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender{
    if([[segue destinationViewController] isKindOfClass:[ShowViewController class]]&&[sender isKindOfClass:[NLTShow class]]){
        [(ShowViewController*)[segue destinationViewController] setShow:sender];
        if(self.playlistContext){
            [(ShowViewController*)[segue destinationViewController] setContextPlaylist:self.playlistContext];
            [(ShowViewController*)[segue destinationViewController] setPlaylistType:self.playlistType];
            self.playlistContext = nil;
            self.playlistType = nil;
        }
    }
    
    if([[segue destinationViewController] isKindOfClass:[ConnectionViewController class]]){
        [(ConnectionViewController*)[segue destinationViewController] setSender:sender];
    }
}


-(UICollectionReusableView *)collectionView:(UICollectionView *)collectionView viewForSupplementaryElementOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath{
    if([kind compare:UICollectionElementKindSectionFooter]==NSOrderedSame){
        FilterFooterCollectionReusableView *footerView = [collectionView dequeueReusableSupplementaryViewOfKind:UICollectionElementKindSectionFooter withReuseIdentifier:@"RecentShowFilterFooter" forIndexPath:indexPath];
        footerView.delegate = self;
        return footerView;
    }
    return nil;
}

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout referenceSizeForFooterInSection:(NSInteger)section{
    if (self.filter == nil || [self.filter compare:@""] == NSOrderedSame) {
        return CGSizeMake(0, 0);
    }else {
        return CGSizeMake(self.collectionView.bounds.size.width, 50);
    }
}

#pragma mark UICollectionViewDelegate

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath{
    self.playlistContext = nil;
    
    if(self.playlistType == nil){
        self.playlistType = @"émissions récentes";
        if(self.family){
            self.playlistType = [NSString stringWithFormat:@"émissions de \"%@\"",self.family.family_TT];
        }
    }
    
    
    NLTShow* show = [self showAtIndex:indexPath.row];
    if(show && show.id_show){
        self.playlistContext = [self allContextShows];
        [self performSegueWithIdentifier:@"DisplayRecentShow" sender:show];
    }
}

- (UIEdgeInsets)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout insetForSectionAtIndex:(NSInteger)section{
    UIEdgeInsets edgeInset = UIEdgeInsetsMake(0,0,0,0);
    if(self.family|| (ALWAYS_DISPLAY_READFILTER_IN_RECENT_SHOWS && [self isMemberOfClass:[RecentShowViewController class]]) ){
        edgeInset = UIEdgeInsetsMake(40,0,0,0);
    }
    return edgeInset;
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation{
    [self fixNavigationBarRelativePosition];
}

- (void)fixNavigationBarRelativePosition{
    if(self.navigationController.navigationBarHidden == FALSE){
        float deltaY = 20 + self.navigationController.navigationBar.frame.size.height - self.collectionView.frame.origin.y ;
        self.collectionView.frame = CGRectMake(self.collectionView.frame.origin.x,
                                               self.collectionView.frame.origin.y + deltaY,
                                               self.collectionView.frame.size.width,
                                               self.collectionView.frame.size.height - deltaY);
        self.filterView.frame = CGRectMake(self.filterView.frame.origin.x,
                                           self.filterView.frame.origin.y + deltaY,
                                           self.filterView.frame.size.width,
                                           self.filterView.frame.size.height);
    }
}
-(void)dealloc{
    [[NLTAPI sharedInstance] cancelCallsWithKey:self];
}
@end
