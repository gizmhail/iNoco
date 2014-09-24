//
//  FavoriteProgramManager.m
//  TestNoco
//
//  Created by Sébastien POIVRE on 04/07/2014.
//  Copyright (c) 2014 Sébastien Poivre. All rights reserved.
//

#import "FavoriteProgramManager.h"

@interface FavoriteProgramManager ()
@end

@implementation FavoriteProgramManager

+ (instancetype)sharedInstance{
    static FavoriteProgramManager* _sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        if(!_sharedInstance){
            _sharedInstance = [[self alloc] init];
        }
    });
    return _sharedInstance;
}

- (FavoriteProgramManager*)init{
    NSUserDefaults* settings = [NSUserDefaults standardUserDefaults];
    self.favoriteFamilies = [NSMutableArray arrayWithObject:@"NOL/CU"];//101% by default ;)
    NSArray* favoriteFamilies = nil;
    if([settings objectForKey:@"favoriteFamilies"]){
        favoriteFamilies = [NSKeyedUnarchiver unarchiveObjectWithData:[settings objectForKey:@"favoriteFamilies"]];
    }
    if(favoriteFamilies){
        self.favoriteFamilies = [NSMutableArray arrayWithArray:favoriteFamilies];
    }
    return self;
}

- (void)setFavorite:(BOOL)isFavorite forFamily:(NLTFamily*)family{
    [self setFavorite:isFavorite forFamilyKey:family.family_key withPartnerKey:family.partner_key];
}


- (void)setFavorite:(BOOL)isFavorite forFamilyKey:(NSString*)familyKey withPartnerKey:(NSString*)partnerKey{
    NSString* familyMergedKey = [NSString stringWithFormat:@"%@/%@",partnerKey,familyKey];
    [self setFavorite:isFavorite forFamilyMergedKey:familyMergedKey];
}

- (void)setFavorite:(BOOL)isFavorite forFamilyMergedKey:(NSString*)familyMergedKey{
    if(isFavorite){
        if(![self.favoriteFamilies containsObject:familyMergedKey]){
            [self.favoriteFamilies addObject:familyMergedKey];
        }
    }else{
        if([self.favoriteFamilies containsObject:familyMergedKey]){
            [self.favoriteFamilies removeObject:familyMergedKey];
        }
    }
    NSUserDefaults* settings = [NSUserDefaults standardUserDefaults];
    NSData* saveData = [NSKeyedArchiver archivedDataWithRootObject:self.favoriteFamilies];
    [settings setObject:saveData forKey:@"favoriteFamilies"];
    [settings synchronize];
}

- (BOOL)isFavoriteForFamilyKey:(NSString*)familyKey withPartnerKey:(NSString*)partnerKey{
    NSString* familyMergedKey = [NSString stringWithFormat:@"%@/%@",partnerKey,familyKey];
    return [self.favoriteFamilies containsObject:familyMergedKey];
}
@end
