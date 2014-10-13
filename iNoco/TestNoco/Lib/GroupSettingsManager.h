//
//  GroupSettingsManager.h
//
//  Created by Sébastien POIVRE on 05/10/2014.
//  Copyright (c) 2014 Sébastien Poivre. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

#ifndef GROUP_SETTINGS_MANAGER_h
#define GROUP_SETTINGS_MANAGER_h
#define GSM_SETTINGS_UPDATE_SUFFIX @"_lastUpdate"
#endif
@interface GroupSettingsManager : NSObject

@property(retain,nonatomic) NSString* defaultSuiteName;

#pragma mark Real methods

+ (instancetype)sharedInstance;

- (void)synchronize;
- (void)synchronizeWithSuiteName:(NSString*)suiteName;

- (id)objectForKey:(NSString*)key;
- (id)objectForKey:(NSString*)key withSuiteName:(NSString*)suiteName;
- (void)setObject:(id)object forKey:(NSString*)key;
- (void)setObject:(id)object forKey:(NSString*)key withSuiteName:(NSString*)suiteName;
- (void)removeObjectForKey:(NSString *)key;
- (void)removeObjectForKey:(NSString *)key withSuiteName:(NSString*)suiteName;

- (void)copyIfNeededFromLocalKeys:(NSArray*)keys;
- (void)copyIfNeededFromLocalKeys:(NSArray*)keys toSuitName:(NSString*)suiteName;

#pragma mark Proxified methods (towards proper NSUserdefaults, either standardUserDefaults or defaultSuiteName one)
- (NSString *)stringForKey:(NSString *)defaultName;
- (NSArray *)arrayForKey:(NSString *)defaultName;
- (NSDictionary *)dictionaryForKey:(NSString *)defaultName;
- (NSData *)dataForKey:(NSString *)defaultName;
- (NSArray *)stringArrayForKey:(NSString *)defaultName;
- (NSInteger)integerForKey:(NSString *)defaultName;
- (float)floatForKey:(NSString *)defaultName;
- (double)doubleForKey:(NSString *)defaultName;
- (BOOL)boolForKey:(NSString *)defaultName;
- (NSURL *)URLForKey:(NSString *)defaultName;

- (void)setInteger:(NSInteger)value forKey:(NSString *)defaultName;
- (void)setFloat:(float)value forKey:(NSString *)defaultName;
- (void)setDouble:(double)value forKey:(NSString *)defaultName;
- (void)setBool:(BOOL)value forKey:(NSString *)defaultName;
- (void)setURL:(NSURL *)url forKey:(NSString *)defaultName;

- (void)logEvent:(NSString*)event withUserInfo:(NSDictionary*)userInfo;
- (NSMutableArray*)logs;

@end
