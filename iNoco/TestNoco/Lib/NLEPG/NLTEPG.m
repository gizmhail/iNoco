//
//  NLTEPG.m
//  TestNoco
//
//  Created by Sébastien POIVRE on 06/07/2014.
//  Copyright (c) 2014 Sébastien Poivre. All rights reserved.
//

#import "NLTEPG.h"

@interface NLTEPG (){
    BOOL useMugen;
}
@property (retain,nonatomic) NSURLConnection* connection;
@property (retain,nonatomic) NSMutableData* data;
@property (retain,nonatomic) NSDate* cacheValidityEnd;
@property (retain,nonatomic) NSMutableArray* cache;
@property (retain,nonatomic) NSXMLParser* parser;
@property (retain,nonatomic) NSError* parserError;
@property (copy,nonatomic) NLTEPGResponseBlock responseBlock;
@property (retain,nonatomic) NSDate* mugenCacheValidityEnd;
@property (retain,nonatomic) NSMutableArray* mugenCache;

@end

@implementation NLTEPG


+ (instancetype)sharedInstance{
    static NLTEPG* _sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        if(!_sharedInstance){
            _sharedInstance = [[self alloc] init];
        }
    });
    return _sharedInstance;
}

- (id)init{
    if(self = [super init]){
        self.useManualParsing = FALSE;
    }
    return self;
}

#pragma mark Catalog

- (void)switchToMugenCatalog{
    useMugen = TRUE;
}

- (void)switchToNolifeCatalog{
    useMugen = FALSE;
}

- (NSString*)catalogUrl{
    NSString* urlStr = @"http://www.nolife-tv.com/noair/noair.xml";
    if(useMugen){
        urlStr = @"http://nolife-tv.com/noair/noair_twitch.xml";
    }
    return urlStr;
}

#pragma mark NSURLConnectionDataDelegate

- (void)fetchEPG:(NLTEPGResponseBlock)responseBlock withCacheDuration:(int)cacheDuration{
    if(useMugen){
        if([self.mugenCache count] == 0){
            NSLog(@"Empty EPG cache");
            self.mugenCache = nil;
        }
    }else{
        if([self.cache count] == 0){
            NSLog(@"Empty EPG cache");
            self.cache = nil;
        }
    }
    NSMutableArray* cache = self.cache;
    NSDate*cacheValidityEnd = self.cacheValidityEnd;
    if(useMugen){
        cache = self.mugenCache;
        cacheValidityEnd = self.mugenCacheValidityEnd;
    }
    if(cache&&[[NSDate date] compare:cacheValidityEnd]==NSOrderedAscending){
        if(responseBlock){
            responseBlock(cache,nil);
        }
    }else{
        NSString* urlStr = [self catalogUrl];
        if(useMugen){
            self.mugenCacheValidityEnd = [[NSDate date] dateByAddingTimeInterval:cacheDuration];
            self.mugenCache = nil;
        }else{
            self.cacheValidityEnd = [[NSDate date] dateByAddingTimeInterval:cacheDuration];
            self.cache = nil;
        }
        NSURLRequest* request = [NSURLRequest requestWithURL:[NSURL URLWithString:urlStr]];
        self.connection = [NSURLConnection connectionWithRequest:request delegate:self];
        if(self.connection){
            NLTEPGResponseBlock previousblock = nil;
            if(self.responseBlock){
                previousblock = self.responseBlock;
            }
            self.responseBlock = ^(NSArray *result, NSError *error) {
                if(previousblock){
                    previousblock(result,error);
                }
                if(responseBlock){
                    responseBlock(result, error);
                }
            };
            if(!previousblock){
#ifdef DEBUG
                NSLog(@"Connecting to %@",urlStr);
#endif
                [self.connection start];            
            }
        }else{
            NSError* error = [NSError errorWithDomain:@"NLTEPGDomain" code:500 userInfo:@{@"message":@"Unable to create connection"}];
            if(responseBlock){
                responseBlock(nil, error);
            }
        }
    }
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response{
    self.data = [NSMutableData data];
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data{
    [self.data appendData:data];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection{
    if(!self.data){
        if(self.responseBlock){
            NSError* error = [NSError errorWithDomain:@"NLTEPGDomain" code:530 userInfo:@{@"message":@"No data"}];
            self.responseBlock(nil, error);
            self.responseBlock = nil;
        }
    }else{
        if(useMugen){
            self.mugenCache = [NSMutableArray array];
        }else{
            self.cache = [NSMutableArray array];
        }
        if(self.useManualParsing){
            [self manualParsing];
        }else{
            self.parser = [[NSXMLParser alloc] initWithData:self.data];
            self.parser.delegate = self;
            self.parserError = nil;
            [self.parser parse];
        }
        
        
        if(self.parserError){
            if(useMugen){
                self.mugenCache = nil;
            }else{
                self.cache = nil;
            }
            if(self.responseBlock){
                self.responseBlock(nil, self.parserError);
                self.responseBlock = nil;
                self.parserError = nil;
            }
        }else{
            BOOL emptyCache = FALSE;
            if(useMugen){
                if([self.mugenCache count]==0){
                    self.mugenCache = nil;
                }
                emptyCache = !self.mugenCache;
            }else{
                if([self.cache count]==0){
                    self.cache = nil;
                }
                emptyCache = !self.cache;
            }
            if(self.responseBlock){
                NSError* error = nil;
                if(emptyCache){
                    error = [NSError errorWithDomain:@"NLTEPGDomain" code:520 userInfo:@{@"message":@"Unknown parse error"}];
                }
                if(useMugen){
                    self.responseBlock(self.mugenCache, error);
                }else{
                    self.responseBlock(self.cache, error);
                }
                self.responseBlock = nil;
            }
        }
    }

}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error{
    if(useMugen){
        self.mugenCache = nil;
    }else{
        self.cache = nil;
    }
    if(self.responseBlock){
        if(!error){
            error = [NSError errorWithDomain:@"NLTEPGDomain" code:510 userInfo:@{@"message":@"Unknown error"}];
        }
        self.responseBlock(nil, error);
        self.responseBlock = nil;
    }
}

#pragma mark NSXMLParserDelegate
- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName attributes:(NSDictionary *)attributeDict{
    //NSLog(@"%@", [attributeDict description]);
    if([elementName compare:@"slot"]==NSOrderedSame){
        if(useMugen){
            [self.mugenCache addObject:attributeDict];
        }else{
            [self.cache addObject:attributeDict];
        }
    }
}

- (void)parser:(NSXMLParser *)parser parseErrorOccurred:(NSError *)parseError{
    self.parserError = parseError;
}

- (BOOL)manualParsing{
    BOOL parsingOk = false;
    if(self.data){
        NSString* raw = [[NSString alloc] initWithData:self.data encoding:NSUTF8StringEncoding];
        if(raw){
            NSError  *error  = NULL;
            
            NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"<slot([^>]*)>" options:0 error:&error];
            NSRegularExpression *regexAttribute = [NSRegularExpression regularExpressionWithPattern:@"([^=]*)=\"([^\"]*)\"" options:0 error:&error];
            
            [regex enumerateMatchesInString:raw options:0 range:NSMakeRange(0, [raw length]) usingBlock:^(NSTextCheckingResult *result, NSMatchingFlags flags, BOOL *stop) {
                NSString* slotContent = [raw substringWithRange:[result rangeAtIndex:1]];
                if(slotContent){
                    NSMutableDictionary* slot = [NSMutableDictionary dictionary];
                    [regexAttribute enumerateMatchesInString:slotContent options:0 range:NSMakeRange(0, [slotContent length]) usingBlock:^(NSTextCheckingResult *result, NSMatchingFlags flags, BOOL *stop) {
                        NSString* kind = [slotContent substringWithRange:[result rangeAtIndex:1]];
                        NSString* value = [slotContent substringWithRange:[result rangeAtIndex:2]];
                        if(kind&&value){
                            kind = [kind stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                            value = [value stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                            [slot setObject:value forKey:kind];
                        }
                        
                    }];
                    if(useMugen){
                        [self.mugenCache addObject:slot];
                    }else{
                        [self.cache addObject:slot];
                    }
                }
            }];
        }
    }
    return parsingOk;
}

- (NSArray*)cachedEPG{
    NSMutableArray* cache = self.cache;
    if(useMugen){
        cache = self.mugenCache;
    }
    if(cache){
        return cache;
    }else{
        return [NSArray array];
    }
}
@end
