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

@interface SearchViewController (){
    int maxShows;
    BOOL initialAuthentCheckDone;
}

@end


@implementation SearchViewController

-(void)viewDidLoad{
    [super viewDidLoad];
    self.title = @"recherche";
    if(self.search){
        self.searchBar.text = self.search;
    }
}


- (void)loadResultsAtPage:(int)page withResultBlock:(NLTCallResponseBlock)responseBlock{
    if(self.search && [self.search compare:@""]!=NSOrderedSame){
        __weak RecentShowViewController* weakSelf = self;
        [[NLTAPI sharedInstance] search:self.search atPage:page withResultBlock:^(id result, NSError *error) {
            [weakSelf.view hideToastActivity];
            if(responseBlock){
                responseBlock(result, error);
            }
        } withKey:self];
    }else{
        [self.view hideToastActivity];
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


#pragma mark UISearchbarDelegate



- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText{
}

- (void)searchBarCancelButtonClicked:(UISearchBar *) searchBar{
    searchBar.text = @"";
    [searchBar resignFirstResponder];
    self.search = nil;
    [self.collectionView reloadData];
}


- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar{
    [self resetResult];
    self.search = searchBar.text;
    [self.collectionView reloadData];
    [self loadResultAtIndex:0];
    [searchBar resignFirstResponder];
}

#pragma mark UICollectioViewDatasource

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section{
    if(!self.search || [self.search compare:@""]==NSOrderedSame){
        return 0;
    }
    return [super collectionView:collectionView numberOfItemsInSection:section];
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath{
    UICollectionViewCell* cell = nil;
    
    NSDictionary* result = [self resultAtIndex:indexPath.row];
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
