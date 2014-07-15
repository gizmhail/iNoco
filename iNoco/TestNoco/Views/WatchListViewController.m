
//
//  WatchListViewController.m
//  TestNoco
//
//  Created by Sébastien POIVRE on 30/06/2014.
//  Copyright (c) 2014 Sébastien Poivre. All rights reserved.
//
#import "NLTOAuth.h"
#import "NLTAPI.h"
#import "UIImageView+WebCache.h"
#import <MediaPlayer/MediaPlayer.h>
#import <QuartzCore/QuartzCore.h>
#import "ShowViewController.h"
#import "WatchListViewController.h"
#import "FavoriteProgramManager.h"
#import "WatchListHeaderReusableView.h"
#import "UIView+Toast.h"
#import "NocoDownloadsManager.h"

@interface WatchListViewController (){
    BOOL initialAuthentCheckDone;
}
@property (retain,nonatomic)NSMutableArray* watchlistIds;
@end
@implementation WatchListViewController


-(void)viewDidLoad{
    [super viewDidLoad];
    self.watchlistIds = [NSMutableArray array];
    self.title = @"à voir";
}

#pragma mark ConnectionViewControllerDelegate

- (void)refreshControlSetup{
}

- (void)connectedToNoco{
    __weak WatchListViewController* weakSelf = self;
    [[NLTAPI sharedInstance] queueListShowIdsWithResultBlock:^(id result, NSError *error) {
        [weakSelf.view hideToastActivity];
        if(error){
#warning TOOD Handle error
        }else{
            weakSelf.watchlistIds = [NSMutableArray arrayWithArray:result];
            [weakSelf.collectionView reloadData];
        }
    } withKey:self];
}

- (void)indexDataUnavailable:(int)index{
    if(index < [self.watchlistIds count]){
        NSNumber* idNumber =  [self.watchlistIds objectAtIndex:index];
        [self.watchlistIds removeObject:idNumber];
    }
}

- (long)downloadsSection{
    if(ALLOW_DOWNLOADS){
        return 0;
    }
    return -1;
}
- (long)watchListSection{
    if(ALLOW_DOWNLOADS){
        return 1;
    }
    return 0;
}

- (long)favoriteFamilySection{
    if(ALLOW_DOWNLOADS){
        return 2;
    }
    return 1;
}

- (long)resumePlaySection{
    if(ALLOW_DOWNLOADS){
        return 3;
    }
    return 2;
}


- (NLTShow*)showAtIndex:(long)showIndex{
    NLTShow* show = nil;
    if(showIndex < [self.watchlistIds count]){
        NSNumber* idNumber =  [self.watchlistIds objectAtIndex:showIndex];
        if([[NLTAPI sharedInstance].showsById objectForKey:idNumber]){
            show = [[NLTAPI sharedInstance].showsById objectForKey:idNumber];
        }else{
            //We want a bit to be sure the call call is still needed
            __weak WatchListViewController* weakSelf = self;
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                UICollectionViewCell* cell = [weakSelf.collectionView cellForItemAtIndexPath:[NSIndexPath indexPathForRow:showIndex inSection:[self watchListSection] ]];
                if([[weakSelf.collectionView visibleCells] containsObject:cell]){
                    [[NLTAPI sharedInstance] showWithId:[idNumber integerValue] withResultBlock:^(id result, NSError *error) {
                        if(!error){
                            if([[NLTAPI sharedInstance].showsById objectForKey:idNumber]){
                                [weakSelf.collectionView reloadData];
                            }else{
                                //Problem with this id: ignoring it
                                [weakSelf indexDataUnavailable:showIndex];
                            }
                        }
                    } withKey:weakSelf];
                }else{
                    //Loading not needed anymore
                    NSLog(@"Loading not needed");
                }
            });
        }
    }
    return show;
}


- (NLTFamily*)familyAtIndex:(long)familyIndex{
    NSString* familyMergedKey = [[[FavoriteProgramManager sharedInstance] favoriteFamilies] objectAtIndex:familyIndex];
    NLTFamily* family = nil;
    if([[NLTAPI sharedInstance].familiesByKey objectForKey:familyMergedKey]){
        family = [[NLTAPI sharedInstance].familiesByKey objectForKey:familyMergedKey];
    }else{
        //We want a bit to be sure the call call is still needed
        __weak WatchListViewController* weakSelf = self;
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            UICollectionViewCell* cell = [weakSelf.collectionView cellForItemAtIndexPath:[NSIndexPath indexPathForRow:familyIndex inSection:1]];
            if([[weakSelf.collectionView visibleCells] containsObject:cell]){
                [[NLTAPI sharedInstance] familyWithFamilyMergedKey:familyMergedKey withResultBlock:^(NLTFamily* newFamily, NSError *error) {
                    BOOL valid = TRUE;
                    if(error&&error.domain == NSCocoaErrorDomain){
                        //Parsing error
                        valid = FALSE;
                    }
                    if(!error){
                        if([[NLTAPI sharedInstance].familiesByKey objectForKey:familyMergedKey]){
                            [weakSelf.collectionView reloadData];
                        }else{
                            //Problem with this id
                            valid = false;
                        }
                    }
                    if(!valid){
                        [[FavoriteProgramManager sharedInstance] setFavorite:false forFamilyMergedKey:familyMergedKey];
                        [self.collectionView reloadData];
                    }
                } withKey:weakSelf];
            }else{
                //Loading not needed anymore
                NSLog(@"Loading not needed");
            }
        });
    }
    return family;
}

- (NLTShow*)downloadedShowAtIndex:(long)showIndex{
    NSArray* infos = [[NocoDownloadsManager sharedInstance] downloadInfos];
    NLTShow* show = nil;
    if([infos count]>showIndex&&[[infos objectAtIndex:showIndex] objectForKey:@"showInfo"]){
        show = [[NLTShow alloc] initWithDictionnary:[[infos objectAtIndex:showIndex] objectForKey:@"showInfo"]];
    }
    return show;
}

#pragma mark UICollectioViewDatasource

-(UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath{
    UICollectionViewCell* cell = nil;
    if(indexPath.section == [self watchListSection] ){
        //Watchlist
        cell = [super collectionView:collectionView cellForItemAtIndexPath:indexPath];
    }else if( indexPath.section == [self favoriteFamilySection] ){
        //Family object
        cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"FamilllyCell" forIndexPath:indexPath];
        cell.layer.borderColor = [[UIColor lightGrayColor] colorWithAlphaComponent:0.4].CGColor;
        [cell.layer setCornerRadius:5.0f];
        cell.layer.borderWidth= 1;
        UIImageView* imageView = (UIImageView*)[cell viewWithTag:100];
        UILabel* title = (UILabel*)[cell viewWithTag:110];
        UILabel* subtitle = (UILabel*)[cell viewWithTag:120];
        imageView.image = [UIImage imageNamed:@"noco.png"];
        title.text = @"Chargement ...";
        subtitle.text = @"";
        NLTFamily* family = [self familyAtIndex:indexPath.row];
        if(family){
            title.text = family.family_TT;
            subtitle.text = family.theme_name;
            if(family.icon_512x288){
#warning Find alternative screenshot when not available
                [imageView sd_setImageWithURL:[NSURL URLWithString:family.icon_512x288] placeholderImage:[UIImage imageNamed:@"noco.png"]];
            }
        }
    }else if( indexPath.section == [self downloadsSection] ){
        NLTShow* show = [self downloadedShowAtIndex:indexPath.row];
        cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"ShowsCell" forIndexPath:indexPath];
        [self loadShowCell:cell withShow:show];
    }
    return cell;
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section{
    if(section == [self watchListSection]){
        //Queued shows
        //self.emptyMessageLabel.hidden = [self.watchlistIds count] != 0;
        return [self.watchlistIds count];
    }else if(section == [self favoriteFamilySection]){
        //Favorite famillies
        return [[[FavoriteProgramManager sharedInstance] favoriteFamilies] count];
    }else if(section == [self downloadsSection]){
        return [[[NocoDownloadsManager sharedInstance] downloadInfos] count];
    }
    return 0;
}

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView{
    if(ALLOW_DOWNLOADS){
        return 3;
    }
    return 2;
}

-(void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath{
    if(indexPath.section == [self watchListSection] ){
        [super collectionView:collectionView didSelectItemAtIndexPath:indexPath];
    }else if(indexPath.section == [self favoriteFamilySection]){
        NLTFamily* family = [self familyAtIndex:indexPath.row];
        if(family && family.family_key){
            [self performSegueWithIdentifier:@"DisplayFamily" sender:family];
        }
    }else if(indexPath.section == [self downloadsSection]){
        NLTShow* show = [self downloadedShowAtIndex:indexPath.row];
        if(show && show.id_show){
            [self performSegueWithIdentifier:@"DisplayRecentShow" sender:show];
        }

    }
}

-(UICollectionReusableView *)collectionView:(UICollectionView *)collectionView viewForSupplementaryElementOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath{
    if([kind compare:UICollectionElementKindSectionHeader]==NSOrderedSame){
        WatchListHeaderReusableView *headerView = [collectionView dequeueReusableSupplementaryViewOfKind:UICollectionElementKindSectionHeader withReuseIdentifier:@"WatchListHeader" forIndexPath:indexPath];
        if(indexPath.section == [self watchListSection]){
            headerView.imageView.image = [UIImage imageNamed:@"eye_btn.png"];
            headerView.imageView.backgroundColor = [UIColor clearColor];
            headerView.label.text = @"Liste de lecture";
        }else if(indexPath.section == [self favoriteFamilySection]){
            headerView.imageView.image = [UIImage imageNamed:@"heart_off.png"];
            headerView.imageView.backgroundColor = [UIColor clearColor];
            headerView.label.text = @"Programmes favoris";
        }else if(indexPath.section == [self downloadsSection]){
            headerView.imageView.image = [UIImage imageNamed:@"download.png"];
            headerView.imageView.backgroundColor = [UIColor clearColor];
            headerView.label.text = @"Emissions téléchargées";
        }
        headerView.label.textColor = [UIColor whiteColor];
        //headerView.backgroundColor = [UIColor lightGrayColor];
        return headerView;
    }
    return nil;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    if(section == [self downloadsSection]){
        if([[[NocoDownloadsManager sharedInstance] downloadInfos] count] == 0){
            return 0;
        }
    }
    return 30;
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender{
    if([[segue destinationViewController] isKindOfClass:[ShowViewController class]]&&[sender isKindOfClass:[NLTShow class]]){
        [(ShowViewController*)[segue destinationViewController] setShow:sender];
    }
    if([[segue destinationViewController] isKindOfClass:[RecentShowViewController class]]&&[sender isKindOfClass:[NLTFamily class]]){
        [(RecentShowViewController*)[segue destinationViewController] setFamily:(NLTFamily*)sender];
    }
}

@end
