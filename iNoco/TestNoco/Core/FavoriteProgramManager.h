//
//  FavoriteProgramManager.h
//  TestNoco
//
//  Created by Sébastien POIVRE on 04/07/2014.
//  Copyright (c) 2014 Sébastien Poivre. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "NLTAPI.h"

@interface FavoriteProgramManager : NSObject
@property (retain,nonatomic)NSMutableArray* favoriteFamilies;

+ (instancetype)sharedInstance;
- (void)setFavorite:(BOOL)isFavorite forFamilyKey:(NSString*)familyKey withPartnerKey:(NSString*)partnerKey;
- (void)setFavorite:(BOOL)isFavorite forFamilyMergedKey:(NSString*)familyMergedKey;
- (void)setFavorite:(BOOL)isFavorite forFamily:(NLTFamily*)family;
- (BOOL)isFavoriteForFamilyKey:(NSString*)familyKey withPartnerKey:(NSString*)partnerKey;
@end
