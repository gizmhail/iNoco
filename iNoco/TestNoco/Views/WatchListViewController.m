
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
}
@property (retain,nonatomic)NSMutableArray* watchlistIds;
@property (retain,nonatomic)NSArray* resumePlayInfo;
@end
@implementation WatchListViewController


-(void)viewDidLoad{
    [super viewDidLoad];
    self.watchlistIds = [NSMutableArray array];
    self.title = @"à voir";
}

-(void)viewDidAppear:(BOOL)animated{
    [super viewDidAppear:animated];
}

#pragma mark Resume play

- (void)refreshResumePlay{
    NSString* urlStr = @"/users/resume_play";
    __weak WatchListViewController* weakSelf = self;
    [[NLTAPI sharedInstance] callAPI:urlStr withResultBlock:^(id result, NSError *error) {
        self.resumePlayInfo = [NSArray array];
        if(!error&&[result isKindOfClass:[NSArray class]]){
            weakSelf.resumePlayInfo = result;
        }
        [weakSelf.collectionView reloadData];
    } withKey:self withCacheDuration:0];

}
#pragma mark ConnectionViewControllerDelegate

- (void)refreshControlSetup{
}

- (void)connectedToNoco{
    __weak WatchListViewController* weakSelf = self;
    [[NLTAPI sharedInstance] queueListShowIdsWithResultBlock:^(id result, NSError *error) {
        [weakSelf hideLoadingActivity];
        if(error){
#warning TOOD Handle error
        }else{
            weakSelf.watchlistIds = [NSMutableArray arrayWithArray:result];
            [weakSelf.collectionView reloadData];
            //We fill resultByPage, as it is used to forward playlists
            [self.resultByPage setObject:weakSelf.watchlistIds forKey:[NSNumber numberWithInt:0]];
        }
    } withKey:self];
    [self refreshResumePlay];

}

- (void)indexDataUnavailable:(long)index{
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
                UICollectionViewCell* cell = [weakSelf.collectionView cellForItemAtIndexPath:[NSIndexPath indexPathForRow:showIndex inSection:[weakSelf watchListSection] ]];
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
                    //NSLog(@"Loading not needed");
                }
            });
        }
    }
    return show;
}

- (NLTShow*)resumePlayShowAtIndex:(long)showIndex{
    NLTShow* show = nil;
    if(showIndex < [self.resumePlayInfo count]){
        NSDictionary* resumePlay = [self.resumePlayInfo objectAtIndex:showIndex];
        NSNumber* idNumber =  [resumePlay objectForKey:@"id_show"];
        if([[NLTAPI sharedInstance].showsById objectForKey:idNumber]){
            show = [[NLTAPI sharedInstance].showsById objectForKey:idNumber];
        }else{
            //We wait a bit to be sure the call is still needed
            __weak WatchListViewController* weakSelf = self;
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                UICollectionViewCell* cell = [weakSelf.collectionView cellForItemAtIndexPath:[NSIndexPath indexPathForRow:showIndex inSection:[weakSelf resumePlaySection] ]];
                if([[weakSelf.collectionView visibleCells] containsObject:cell]){
                    [[NLTAPI sharedInstance] showWithId:[idNumber integerValue] withResultBlock:^(id result, NSError *error) {
                        if(!error){
                            if([[NLTAPI sharedInstance].showsById objectForKey:idNumber]){
                                [weakSelf.collectionView reloadData];
                            }else{
                                //Problem with this id: ignoring it
                                if(showIndex < [weakSelf.resumePlayInfo count]){
                                    [self.watchlistIds removeObject:resumePlay];
                                }
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
    return show;
}


- (NLTFamily*)familyAtIndex:(long)familyIndex{
    NSString* familyMergedKey = [[[FavoriteProgramManager sharedInstance] favoriteFamilies] objectAtIndex:familyIndex];
    NLTFamily* family = nil;
    if([[NLTAPI sharedInstance].familiesByKey objectForKey:familyMergedKey]){
        family = [[NLTAPI sharedInstance].familiesByKey objectForKey:familyMergedKey];
    }else{
        //We wait a bit to be sure the call is still needed
        __weak WatchListViewController* weakSelf = self;
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            UICollectionViewCell* cell = [weakSelf.collectionView cellForItemAtIndexPath:[NSIndexPath indexPathForRow:familyIndex inSection:[weakSelf favoriteFamilySection]]];
            if([[weakSelf.collectionView visibleCells] containsObject:cell]){
#warning TODO Understand why familyMergedKey is nilled sometimes (for index 1)
                NSString* familyMergedKey = [[[FavoriteProgramManager sharedInstance] favoriteFamilies] objectAtIndex:familyIndex];
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
                //NSLog(@"Loading not needed");
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

- (NSMutableArray*)allDownloadedContextShows{
    NSMutableArray* shows = [NSMutableArray array];
    NSArray* infos = [[NocoDownloadsManager sharedInstance] downloadInfos];
    for (NSDictionary* info in infos) {
        if([info objectForKey:@"showInfo"]){
            NLTShow* show = [[NLTShow alloc] initWithDictionnary:[info objectForKey:@"showInfo"]];
            [shows addObject:show];
        }
    }
    return shows;
}

- (NSMutableArray*)allResumeShows{
    NSMutableArray* shows = [NSMutableArray array];
    for (NSDictionary* resumePlay in self.resumePlayInfo) {
        NSNumber* idNumber =  [resumePlay objectForKey:@"id_show"];
        if([[NLTAPI sharedInstance].showsById objectForKey:idNumber]){
            NLTShow* show = [[NLTAPI sharedInstance].showsById objectForKey:idNumber];
            [shows addObject:show];
        }
    }
    return shows;
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
        NLTFamily* family = [self familyAtIndex:indexPath.row];
        if([cell isKindOfClass:[ShowCollectionViewCell class]]){
            [(ShowCollectionViewCell*)cell loadFamily:family];
        }else{
            NSLog(@"PB with cell loading");
        }
    }else if( indexPath.section == [self downloadsSection] ){
        NLTShow* show = [self downloadedShowAtIndex:indexPath.row];
        cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"ShowsCell" forIndexPath:indexPath];
        [self loadShowCell:(ShowCollectionViewCell*)cell withShow:show];
    }else if( indexPath.section == [self resumePlaySection] ){
        NLTShow* show = [self resumePlayShowAtIndex:indexPath.row];
        cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"ShowsCell" forIndexPath:indexPath];
        [self loadShowCell:(ShowCollectionViewCell*)cell withShow:show];
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
    }else if(section == [self resumePlaySection]){
        return [self.resumePlayInfo count];
    }
    return 0;
}

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView{
    if(ALLOW_DOWNLOADS){
        return 4;
    }
    return 3;
}

-(void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath{
    self.playlistContext = nil;
    if(indexPath.section == [self watchListSection] ){
        self.playlistType = @"émissions de la liste de lecture";
        [super collectionView:collectionView didSelectItemAtIndexPath:indexPath];
    }else if(indexPath.section == [self favoriteFamilySection]){
        NLTFamily* family = [self familyAtIndex:indexPath.row];
        if(family && family.family_key){
            [self performSegueWithIdentifier:@"DisplayFamily" sender:family];
        }
    }else if(indexPath.section == [self downloadsSection]){
        NLTShow* show = [self downloadedShowAtIndex:indexPath.row];
        if(show && show.id_show){
            if(self.playlistType == nil){
                self.playlistType = @"émissions téléchargées";
            }

            self.playlistContext = [self allDownloadedContextShows];
            [self performSegueWithIdentifier:@"DisplayRecentShow" sender:show];
        }
    }else if(indexPath.section == [self resumePlaySection]){
        NLTShow* show = [self resumePlayShowAtIndex:indexPath.row];
        if(show && show.id_show){
            if(self.playlistType == nil){
                self.playlistType = @"émissions commencées";
            }
            self.playlistContext = [self allResumeShows];
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
            headerView.imageView.image = [[UIImage imageNamed:@"download.png"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
            headerView.imageView.backgroundColor = [UIColor clearColor];
            headerView.label.text = @"Emissions téléchargées";
        }else if(indexPath.section == [self resumePlaySection]){
            headerView.imageView.image = [[UIImage imageNamed:@"downloadPending.png"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
            headerView.imageView.backgroundColor = [UIColor clearColor];
            headerView.label.text = @"Emissions commencées";
        }
        headerView.imageView.tintColor = [UIColor whiteColor];
        headerView.label.textColor = [UIColor whiteColor];
        //headerView.backgroundColor = [UIColor lightGrayColor];
        return headerView;
    }
    return nil;
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
    if([[segue destinationViewController] isKindOfClass:[RecentShowViewController class]]&&[sender isKindOfClass:[NLTFamily class]]){
        [(RecentShowViewController*)[segue destinationViewController] setFamily:(NLTFamily*)sender];
    }
    if([[segue destinationViewController] isKindOfClass:[ConnectionViewController class]]){
        [(ConnectionViewController*)[segue destinationViewController] setSender:sender];
    }
}

@end
