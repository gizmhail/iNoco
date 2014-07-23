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

@interface RecentShowViewController ()
@property (retain,nonatomic)UIButton* favoriteFamilly;
@property (retain,nonatomic)UIRefreshControl* refreshControl;
@property (retain,nonatomic)UIAlertView* errorAlert;
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
    
    self.refreshControl.attributedTitle = [[NSAttributedString alloc] initWithString:@"Tirer pour rafraichir"];
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
    [self.view makeToastActivity];
    initialAuthentCheckDone = FALSE;
    [self refreshResult];

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

#pragma mark ConnectionViewControllerDelegate

- (void) forceRefreshResult{
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
#warning TODO Handle offline
        initialAuthentCheckDone = TRUE;
        if(!authenticated){
            [weakSelf.view hideToastActivity];
            [weakSelf.navigationController.tabBarController performSegueWithIdentifier:@"NotConnectedSegue" sender:nil];
            [weakSelf.refreshControl endRefreshing];
        }else{
            [weakSelf connectedToNoco];
            //Fetch partners logo
            [[NLTAPI sharedInstance] partnersWithResultBlock:^(id result, NSError *error) {
                [self.collectionView reloadData];
            } withKey:self];
        }
        UIAccessibilityPostNotification(UIAccessibilityLayoutChangedNotification, self.collectionView);
    }];
}

- (void)resetResult{
    maxShows = -1;
    self.resultByPage = [NSMutableDictionary dictionary];
    self.filteredResultByPage = [NSMutableDictionary dictionary];
}
- (void)connectedToNoco{
    [self loadResultAtIndex:0];
}

- (long)greatestFetchedPage{
    return [[[self.resultByPage allKeys] valueForKeyPath:@"@max.intValue"] integerValue];
}

- (void)loadResultAtIndex:(int)resultIndex{
    NSIndexPath* indexPath = [self pageAndIndexInPageFor:resultIndex];
    int page = (int) indexPath.section;
    __weak RecentShowViewController* weakSelf = self;
    if(![self.resultByPage objectForKey:[NSNumber numberWithInt:page]]){
        [[NLTOAuth sharedInstance]isAuthenticatedAfterRefreshTokenUse:^(BOOL authenticated, NSError* error) {
            if(authenticated){
                if(weakSelf.filter && page > [weakSelf greatestFetchedPage]){
                    //If filtering, we don't download additionnal pages (unless some pages were missing, skipped due to high speed scrolling)
                    [weakSelf.view hideToastActivity];
                }else if([self.resultByPage objectForKey:[NSNumber numberWithInt:page-1]]&&[[self.resultByPage objectForKey:[NSNumber numberWithInt:page-1]] count]==0){
                    //We already known that the last page is empty : no need to go further
                    maxShows = [self entriesBeforePage:page];
                    [weakSelf.collectionView reloadData];
                }else{
                    [weakSelf.view makeToastActivity];
                    [weakSelf loadResultsAtPage:page withResultBlock:^(id result, NSError *error) {
                        [weakSelf.view hideToastActivity];
                        [weakSelf.refreshControl endRefreshing];
                        if(error){
                            maxShows = [self entriesBeforePage:page];
                            if(!self.errorAlert){
                                self.errorAlert = [[UIAlertView alloc] initWithTitle:@"Erreur" message:@"Impossible de se connecter. Veuillez vérifier votre connection." delegate:self   cancelButtonTitle:@"Ok" otherButtonTitles:nil];
                                [self.errorAlert show];
                            }
                            [weakSelf.collectionView reloadData];
                        }else{
                            [weakSelf insertPageResult:page withResult:result withError:error];
                        }
                    }];
                }
            }else{
#warning TODO Handle offline
                [weakSelf.view hideToastActivity];
                [weakSelf.refreshControl endRefreshing];
            }
        }];
    }else{
        [self.view hideToastActivity];
        [self.refreshControl endRefreshing];
    }
}

- (void)loadResultsAtPage:(int)page withResultBlock:(NLTCallResponseBlock)responseBlock{
    [[NLTAPI sharedInstance] showsAtPage:page withResultBlock:responseBlock withFamilyKey:self.family.family_key withKey:self];

}

- (long)entriesBeforePage:(int)page{
    long entries = 0;
    NSDictionary* pageDictionary = self.resultByPage;
    if(self.filter){
        pageDictionary = self.filteredResultByPage;
    }
    for (NSNumber* pageResultsIndex in [pageDictionary allKeys]) {
        if([pageResultsIndex integerValue]>page){
            continue;
        }
        NSArray* pageResults = [pageDictionary objectForKey:pageResultsIndex];
        entries += [pageResults count];
    }
    return entries;
}

- (void)insertPageResult:(int)page withResult:(id)result withError:(NSError*)error{
    if(result&&[result isKindOfClass:[NSArray class]]){
        if([(NSArray*)result count]<[[NLTAPI sharedInstance] resultsByPage]){
            //End of available shows (not a full page of results)
            maxShows = [(NSArray*)result count] + [self entriesBeforePage:page];
        }
        [self.resultByPage setObject:[NSMutableArray arrayWithArray:result] forKey:[NSNumber numberWithInt:page]];
        [self filterShowsAtPage:page];
        [self.collectionView reloadData];
        UIAccessibilityPostNotification(UIAccessibilityLayoutChangedNotification, self.collectionView);
    }else{
        //TODO Handle error
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
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            UICollectionViewCell* cell = [self.collectionView cellForItemAtIndexPath:[NSIndexPath indexPathForRow:showIndex inSection:0]];
            if([[self.collectionView visibleCells] containsObject:cell]){
                [self loadResultAtIndex:showIndex];
            }else{
                //Loading not needed anymore
                NSLog(@"Loading not needed");
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
            [self filterShowsAtPage:[page integerValue]];
            total += [[self.resultByPage objectForKey:page] count];
            filtered += [[self.filteredResultByPage objectForKey:page] count];
        }
    }
    NSLog(@"Filter : %i / %i",filtered, total);
}

- (void)filterShowsAtPage:(int)page{
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
            [self.filteredResultByPage setObject:filteredShows forKey:[NSNumber numberWithInt:page]];
        }
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
}


- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar{
    self.filter = searchBar.text;
    [self filterShowsWithString];
    //[self.collectionView reloadItemsAtIndexPaths:[self.collectionView indexPathsForVisibleItems]];
    [self.collectionView reloadData];
    UIAccessibilityPostNotification(UIAccessibilityLayoutChangedNotification, @"Annulation du filtre");
    [searchBar resignFirstResponder];
    [[UISegmentedControl appearanceWhenContainedIn:[UISearchBar class], nil] setTintColor:searchBar.tintColor];
}

/*
- (BOOL)searchBarShouldBeginEditing:(UISearchBar *)searchBar {
    [searchBar setScopeButtonTitles:@[@"Tous", @"Non lu"]];
    searchBar.showsScopeBar = YES;
    [searchBar sizeToFit];
    [searchBar setShowsCancelButton:YES animated:YES];
    
    return YES;
}

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
    if(!initialAuthentCheckDone){
        return 0;
    }
    if(self.filter){
        int maxPage = [self greatestFetchedPage];
        int page =  0 ;
        int total = 0;
        while(page <= maxPage){
            NSArray* filteredShowsInPage = [self.filteredResultByPage objectForKey:[NSNumber numberWithInt:page]];
            int pageCount = [[NLTAPI sharedInstance] resultsByPage];
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
    }
}

#pragma mark UICollectionViewDelegate

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath{
    NLTShow* show = [self showAtIndex:indexPath.row];
    if(show && show.id_show){
        [self performSegueWithIdentifier:@"DisplayRecentShow" sender:show];
    }
}

-(void)dealloc{
    [[NLTAPI sharedInstance] cancelCallsWithKey:self];
}
@end
