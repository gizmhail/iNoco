//
//  NLTEPG.h
//  TestNoco
//
//  Created by Sébastien POIVRE on 06/07/2014.
//  Copyright (c) 2014 Sébastien Poivre. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef void (^NLTEPGResponseBlock)(NSArray* result, NSError *error);

@interface NLTEPG : NSObject<NSURLConnectionDataDelegate, NSXMLParserDelegate>
@property(assign,nonatomic)BOOL useManualParsing;

+ (instancetype)sharedInstance;
- (void)fetchEPG:(NLTEPGResponseBlock)responseBlock withCacheDuration:(int)cacheDuration;
- (NSArray*)cachedEPG;
@end
