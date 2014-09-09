//
//  SearchViewController.m
//  TestNoco
//
//  Created by Sébastien POIVRE on 01/07/2014.
//  Copyright (c) 2014 Sébastien Poivre. All rights reserved.
//

#import "SearchViewController.h"
#import "NLTAPI.h"
#import "UIImageView+WebCache.h"
#import <MediaPlayer/MediaPlayer.h>
#import <QuartzCore/QuartzCore.h>
#import "ShowViewController.h"
#import "UIView+Toast.h"
#import "FamilyTableViewCell.h"

@interface SearchViewController (){
    int maxShows;
    BOOL emptyFamilyPageFound;
    int pendingFamilyPageCalls;
    int maxFamily;
    BOOL useFamilyList;
}

@property (retain, nonatomic) NSMutableDictionary* familiesByPage;
@end


@implementation SearchViewController

- (BOOL)enableFamilyList{
    return useFamilyList;
}

-(void)viewDidLoad{
    [self loadFamilyListPreference];
    [super viewDidLoad];
    maxFamily = -1;
    self.familiesByPage = [NSMutableDictionary dictionary];
    self.title = @"recherche";
    if(self.search){
        self.searchBar.text = self.search;
    }
}

-(void)loadFamilyListPreference{
    NSUserDefaults* settings = [NSUserDefaults standardUserDefaults];
    useFamilyList = FALSE;
    if([settings objectForKey:@"FamilyList"]){
        useFamilyList = [[settings objectForKey:@"FamilyList"] boolValue];
    }
#ifdef DEBUG
    //useFamilyList = TRUE;
#endif

}

- (void)resetResult{
    [super resetResult];
    maxFamily = -1;
    self.familiesByPage = [NSMutableDictionary dictionary];
    emptyFamilyPageFound = FALSE;
}

- (void)connectedToNoco{
    [super connectedToNoco];
    [self loadTableFamilyAtIndex:[NSIndexPath indexPathForItem:0 inSection:0]];
}

- (void)loadResultsAtPage:(int)page withResultBlock:(NLTCallResponseBlock)responseBlock{
    if(self.search && [self.search compare:@""]!=NSOrderedSame){
        __weak RecentShowViewController* weakSelf = self;
        [[NLTAPI sharedInstance] search:self.search atPage:page withResultBlock:^(id result, NSError *error) {
            [weakSelf.view hideToastActivity];
            if(error){
                [self checkErrorForQuotaLimit:error];
            }
            if(responseBlock){
                responseBlock(result, error);
            }
        } withKey:self];
    }else{
        if(responseBlock){
            responseBlock([NSArray array], nil);
        }
        //[self.view hideToastActivity];
    }
}

- (void)indexDataUnavailable:(long)index{
    [self removeResultAtIndex:index];
    [self.collectionView reloadData];
}

- (void)filterShowsAtPage:(int)page{
}

- (NLTShow*)showAtIndex:(long)showIndex{
    NSDictionary* result = [self resultAtIndex:showIndex];
    NLTShow* show = nil;
    if([result objectForKey:@"type"]&&[(NSString*)[result objectForKey:@"type"] compare:@"show"]==NSOrderedSame){
        if([result objectForKey:@"id"]){
            NSNumber* idNumber =  [result objectForKey:@"id"];
            if([[NLTAPI sharedInstance].showsById objectForKey:idNumber]){
                show = [[NLTAPI sharedInstance].showsById objectForKey:idNumber];
            }else{
                //We want a bit to be sure the call call is still needed
                __weak SearchViewController* weakSelf = self;

                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    UICollectionViewCell* cell = [weakSelf.collectionView cellForItemAtIndexPath:[NSIndexPath indexPathForRow:showIndex inSection:0]];
                    if([[weakSelf.collectionView visibleCells] containsObject:cell]){
                        [[NLTAPI sharedInstance] showWithId:[idNumber integerValue] withResultBlock:^(NLTShow* newShow, NSError *error) {
                            BOOL valid = TRUE;
                            [self checkErrorForQuotaLimit:error];

                            if(error&&error.domain == NSCocoaErrorDomain){
                                //Parsing error
                                valid = FALSE;
                            }
                            if(!error){
                                if([[NLTAPI sharedInstance].showsById objectForKey:idNumber]){
                                    [weakSelf.collectionView reloadData];
                                }else{
                                    //Problem with this id
                                    valid = false;
                                }
                            }
                            if(!valid){
                                //As we can remove entries, index might not be the good one anymore
                                long newShowIndex = showIndex;
                                NSDictionary* currentResultAtExpectedIndex = [weakSelf resultAtIndex:showIndex];
                                if(currentResultAtExpectedIndex != result){
                                    NSIndexPath* indexPath = [weakSelf pageAndIndexInPageFor:showIndex];
                                    long page = indexPath.section;
                                    NSDictionary* pageDictionary = weakSelf.resultByPage;
                                    if(weakSelf.filter){
                                        pageDictionary = weakSelf.filteredResultByPage;
                                    }
                                    NSArray* pageResults = [pageDictionary objectForKey:[NSNumber numberWithInt:(int)page]];
                                    if([pageResults containsObject:result]){
                                        NSLog(@"Remove entry not found: %@",result);
                                        newShowIndex = [pageResults indexOfObject:result];
                                        [weakSelf indexDataUnavailable:newShowIndex];
                                    }
                                }else{
                                    NSLog(@"Remove entry not found: %@",result);
                                    [weakSelf indexDataUnavailable:newShowIndex];
                                }
                            }
                        } withKey:weakSelf];
                    }else{
                        //Loading not needed anymore
                        //NSLog(@"Loading not needed");
                    }
                });
            }
        }
    }
    return show;
}

- (NLTFamily*)familyAtIndex:(long)familyIndex{
    NSDictionary* result = [self resultAtIndex:familyIndex];
    NLTFamily* family = nil;
    if([result objectForKey:@"type"]&&[(NSString*)[result objectForKey:@"type"] compare:@"family"]==NSOrderedSame){
        if([result objectForKey:@"id"]){
            NSNumber* idNumber =  [result objectForKey:@"id"];
            if([[NLTAPI sharedInstance].familiesById objectForKey:idNumber]){
                family = [[NLTAPI sharedInstance].familiesById objectForKey:idNumber];
            }else{
                //We want a bit to be sure the call call is still needed
                __weak SearchViewController* weakSelf = self;

                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    UICollectionViewCell* cell = [weakSelf.collectionView cellForItemAtIndexPath:[NSIndexPath indexPathForRow:familyIndex inSection:0]];
                    if([[weakSelf.collectionView visibleCells] containsObject:cell]){
                        [[NLTAPI sharedInstance] familyWithId:[idNumber integerValue] withResultBlock:^(NLTFamily* newFamily, NSError *error) {
                            BOOL valid = TRUE;
                            if(error&&error.domain == NSCocoaErrorDomain){
                                //Parsing error
                                valid = FALSE;
                            }
                            if(!error){
                                if([[NLTAPI sharedInstance].familiesById objectForKey:idNumber]){
                                    [weakSelf.collectionView reloadData];
                                }else{
                                    //Problem with this id
                                    valid = false;
                                }
                            }
                            if(!valid){
                                //As we can remove entries, index might not be the good one anymore
                                long newFamilyIndex = familyIndex;
                                NSDictionary* currentResultAtExpectedIndex = [weakSelf resultAtIndex:familyIndex];
                                if(currentResultAtExpectedIndex != result){
                                    NSIndexPath* indexPath = [weakSelf pageAndIndexInPageFor:familyIndex];
                                    long page = indexPath.section;
                                    NSDictionary* pageDictionary = weakSelf.resultByPage;
                                    if(weakSelf.filter){
                                        pageDictionary = weakSelf.filteredResultByPage;
                                    }
                                    NSArray* pageResults = [pageDictionary objectForKey:[NSNumber numberWithInt:(int)page]];
                                    if([pageResults containsObject:result]){
                                        NSLog(@"Remove entry not found: %@",result);
                                        newFamilyIndex = [pageResults indexOfObject:result];
                                        [weakSelf indexDataUnavailable:newFamilyIndex];
                                    }
                                }else{
                                    NSLog(@"Remove entry not found: %@",result);
                                    [weakSelf indexDataUnavailable:newFamilyIndex];
                                }
                            }
                        } withKey:weakSelf];
                    }else{
                        //Loading not needed anymore
                        //NSLog(@"Loading not needed");
                    }
                });
            }
        }
    }
    return family;
}

- (void)updateDisplayedContainer{
    if(!self.search || [self.search compare:@""]==NSOrderedSame){
        self.collectionView.hidden = true;
        self.familyTableview.hidden = false;
    }else{
        self.collectionView.hidden = false;
        self.familyTableview.hidden = true;
    }
}

#pragma mark UISearchbarDelegate

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText{
}

- (void)searchBarCancelButtonClicked:(UISearchBar *) searchBar{
    searchBar.text = @"";
    [searchBar resignFirstResponder];
    self.search = nil;
    [self updateDisplayedContainer];
    [self.collectionView reloadData];
    [self.familyTableview reloadData];
}


- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar{
    [self resetResult];
    self.search = searchBar.text;
    [self updateDisplayedContainer];
    [self.collectionView reloadData];
    [self.familyTableview reloadData];
    [self loadResultAtIndex:0];
    [searchBar resignFirstResponder];
}

#pragma mark - Families list

- (NSIndexPath*)positionInResultsForTableFamilyAtIndexPath:(NSIndexPath*)indexPath{
    long page = 0;
    long indexInPage = 0;
    long remainingIndex = indexPath.row;
    int currentPage = 0;
    while(remainingIndex >= 0){
        //Default page count if page not fetched
        long pageCount = (long)[[NLTAPI sharedInstance] resultsByPage];
        NSArray* resultsInPage = [self.familiesByPage objectForKey:[NSNumber numberWithInt:currentPage]];
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

- (id)loadedTableFamilyAtIndexPath:(NSIndexPath*)indexPath{
    NSIndexPath* positionInResults = [self positionInResultsForTableFamilyAtIndexPath:indexPath];
    long page = positionInResults.section;
    long indexInPage = positionInResults.row;

    id result = nil;
    NSArray* pageResults = [self.familiesByPage objectForKey:[NSNumber numberWithInt:(int)page]];
    if(pageResults){
        if([pageResults count]>indexInPage){
            result = [pageResults objectAtIndex:indexInPage];
        }else{
            NSLog(@"Index PB");
        }
    }
    return result;
}

- (NLTFamily*)familyInTableAtIndex:(NSIndexPath*)indexPath{
    NLTFamily* family = [self loadedTableFamilyAtIndexPath:indexPath];
    if(!family){
        //We want a bit to be sure the call call is still needed
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            UITableViewCell* cell = [self.familyTableview cellForRowAtIndexPath:indexPath];
            if([[self.familyTableview visibleCells] containsObject:cell]){
                [self loadTableFamilyAtIndex:indexPath];
            }else{
                //NSLog(@"Loading not needed");
            }
        });
    }
    return family;
}

- (long)tableEntriesCount{
    long entries = 0;
    NSDictionary* pageDictionary = self.familiesByPage;
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

- (void)loadTableFamilyAtIndex:(NSIndexPath*)indexPath{
    if(![self enableFamilyList]){
        return ;
    }

    NSIndexPath* positionInResults = [self positionInResultsForTableFamilyAtIndexPath:indexPath];
    long page = positionInResults.section;
    __weak SearchViewController* weakSelf = self;
    if(![self.familiesByPage objectForKey:[NSNumber numberWithInt:page]]){
        [[NLTOAuth sharedInstance]isAuthenticatedAfterRefreshTokenUse:^(BOOL authenticated, NSError* error) {
            if(authenticated){
                [weakSelf.view makeToastActivity];
                pendingFamilyPageCalls++;
                [[NLTAPI sharedInstance] familiesAtPage:page withResultBlock:^(id result, NSError *error) {
                    pendingFamilyPageCalls--;
                    [weakSelf.view hideToastActivity];
                    if(error){
                        
                        BOOL quotaError = [self checkErrorForQuotaLimit:error];
                        maxFamily = [self tableEntriesCount];
#ifdef DEBUG
                        NSLog(@"maxFamily (%i) set due to error in page fetching", maxFamily);
#endif
                        if(!self.errorAlert&&!quotaError){
                            self.errorAlert = [[UIAlertView alloc] initWithTitle:@"Erreur" message:@"Impossible de se connecter. Veuillez vérifier votre connection." delegate:self   cancelButtonTitle:@"Ok" otherButtonTitles:nil];
                            [self.errorAlert show];
                        }
                        [weakSelf.collectionView reloadData];
                    }else{
                        if(result&&[result isKindOfClass:[NSArray class]]){
                            if([(NSArray*)result count]<[[NLTAPI sharedInstance] resultsByPage]){
                                //End of available shows (not a full page of results)
#ifdef DEBUG
                                NSLog(@"Empty family page found (%i)",page);
#endif
                                emptyFamilyPageFound = TRUE;
                            }
                            [self.familiesByPage setObject:[NSMutableArray arrayWithArray:result] forKey:[NSNumber numberWithInt:page]];
                            [self.familyTableview reloadData];
                            UIAccessibilityPostNotification(UIAccessibilityLayoutChangedNotification, self.familyTableview);
                        }else{
                            //TODO Handle error
                            NSLog(@"Unexpected page result");
                        }
                    }
                    if(emptyFamilyPageFound){
                        if(pendingFamilyPageCalls <= 0){
                            maxFamily = [self tableEntriesCount];
#ifdef DEBUG
                            NSLog(@"maxFamily (%i) set due to current emptyFamilyPageFound and pendingFamilyPageCalls == 0", maxFamily);
#endif
                            
                            [weakSelf.familyTableview reloadData];
                        }else{
#ifdef DEBUG
                            NSLog(@"Empty page found, but still %i calls pending", pendingFamilyPageCalls);
#endif
                        }
                    }
                } withKey:self];
            }else{
#warning TODO Handle offline
                [weakSelf.view hideToastActivity];
            }
        }];
    }else{
        [self.view hideToastActivity];
    }
}




#pragma mark UITableViewDelegate


- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView{
    if(![self enableFamilyList]){
        return 0;
    }
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section{
    if(![self enableFamilyList]){
        return 0;
    }
    if(!self.initialAuthentCheckDone){
        return 0;
    }
    if(maxFamily == -1){
        //While we don't know the end
        return 2000;
    }
    return maxFamily;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath{
    NLTFamily* family = [self familyInTableAtIndex:indexPath];
    FamilyTableViewCell *cell = (FamilyTableViewCell*)[tableView dequeueReusableCellWithIdentifier:@"FamilyCell" forIndexPath:indexPath];
    UILabel* familyNameLabel = (UILabel*)[cell viewWithTag:200];
    UILabel* episodeCountLabel = (UILabel*)[cell viewWithTag:230];
    UILabel* resumeLabel = (UILabel*)[cell viewWithTag:240];
    UILabel* themeLabel = (UILabel*)[cell viewWithTag:250];
    UIImageView* familyImageView = (UIImageView*)[cell viewWithTag:220];
    UIImageView* partnerImageView = (UIImageView*)[cell viewWithTag:600];
    partnerImageView.image = nil;
    familyImageView.image = [UIImage imageNamed:@"noco.png"];
    if(family){
        familyNameLabel.text = family.family_TT;
        if(family.icon_512x288){
#warning Find alternative screenshot when not available
            [familyImageView sd_setImageWithURL:[NSURL URLWithString:family.icon_512x288] placeholderImage:[UIImage imageNamed:@"noco.png"]];
        }
        if(family.nb_shows == 1){
            episodeCountLabel.text = @"1 épisode";
        }else{
            episodeCountLabel.text = [NSString stringWithFormat:@"%i épisodes", family.nb_shows];
        }
        resumeLabel.text = family.family_resume;
        themeLabel.text = family.theme_name;
        if([[NLTAPI sharedInstance].partnersByKey objectForKey:family.partner_key]){
            NSDictionary* partnerInfo = [[NLTAPI sharedInstance].partnersByKey objectForKey:family.partner_key];
            if([partnerInfo objectForKey:@"icon_128x72"]){
                [partnerImageView sd_setImageWithURL:[NSURL URLWithString:[partnerInfo objectForKey:@"icon_128x72"]] placeholderImage:nil];
            }
        }
    }else{
        episodeCountLabel.text = @"";
        resumeLabel.text = @"";
        themeLabel.text = @"";
        familyNameLabel.text = @"Chargement ...";
        familyImageView.image = [UIImage imageNamed:@"noco.png"];
    }
    return cell;
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    NLTFamily* family = [self familyInTableAtIndex:indexPath];
    if(family && family.family_key){
        [self performSegueWithIdentifier:@"DisplayFamily" sender:family];
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath{
    if(UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone){
        NLTFamily* family = [self familyInTableAtIndex:indexPath];
        if(family){
            if(!family.family_resume || [[family.family_resume stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] compare:@""]==NSOrderedSame){
                return 60;
            }
        }
    }
    return 120;
}

#pragma mark UICollectioViewDatasource

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section{
    self.noResultLabel.hidden = TRUE;
    if(!self.search || [self.search compare:@""]==NSOrderedSame){
        return 0;
    }
    int resultCount = [super collectionView:collectionView numberOfItemsInSection:section];
    if(resultCount == 0){
        self.noResultLabel.hidden = FALSE;
    }else{
        self.noResultLabel.hidden = TRUE;
    
    }
    return resultCount;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath{
    UICollectionViewCell* cell = nil;
    
    NSDictionary* result = [self resultAtIndex:indexPath.row];
    if(!result){
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            UICollectionViewCell* cell = [self.collectionView cellForItemAtIndexPath:indexPath];
            if([[self.collectionView visibleCells] containsObject:cell]){
                [self loadResultAtIndex:indexPath.row];
            }else{
                //Loading not needed anymore
                //NSLog(@"Loading not needed");
            }
        });
    }
    if([result objectForKey:@"type"]&&[(NSString*)[result objectForKey:@"type"] compare:@"show"]==NSOrderedSame){
        //Show object
        return [super collectionView:collectionView cellForItemAtIndexPath:indexPath];
    }else{
        //Family object
        cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"FamilllyCell" forIndexPath:indexPath];
        NLTFamily* family = [self familyAtIndex:indexPath.row];
        if([cell isKindOfClass:[ShowCollectionViewCell class]]){
            [(ShowCollectionViewCell*)cell loadFamily:family];
        }else{
            NSLog(@"PB with cell loading");
        }
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
    if([[segue destinationViewController] isKindOfClass:[RecentShowViewController class]]&&[sender isKindOfClass:[NLTFamily class]]){
        [(RecentShowViewController*)[segue destinationViewController] setFamily:(NLTFamily*)sender];
    }
    if([[segue destinationViewController] isKindOfClass:[ConnectionViewController class]]){
        [(ConnectionViewController*)[segue destinationViewController] setSender:sender];
    }
}

#pragma mark UICollectionViewDelegate

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath{
    NSDictionary* result = [self resultAtIndex:indexPath.row];
    if([result objectForKey:@"type"]&&[(NSString*)[result objectForKey:@"type"] compare:@"show"]==NSOrderedSame){
        NLTShow* show = [self showAtIndex:indexPath.row];
        if(show && show.id_show){
            [self performSegueWithIdentifier:@"DisplayRecentShow" sender:show];
        }
    }else{
        NLTFamily* family = [self familyAtIndex:indexPath.row];
        if(family && family.family_key){
            [self performSegueWithIdentifier:@"DisplayFamily" sender:family];
        }
    }
}

@end
