//
//  NLTEPG.m
//  TestNoco
//
//  Created by Sébastien POIVRE on 06/07/2014.
//  Copyright (c) 2014 Sébastien Poivre. All rights reserved.
//

#import "NLTEPG.h"

@interface NLTEPG ()
@property (retain,nonatomic) NSURLConnection* connection;
@property (retain,nonatomic) NSMutableData* data;
@property (retain,nonatomic) NSDate* cacheValidityEnd;
@property (retain,nonatomic) NSMutableArray* cache;
@property (retain,nonatomic) NSXMLParser* parser;
@property (retain,nonatomic) NSError* parserError;
@property (copy,nonatomic) NLTEPGResponseBlock responseBlock;

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

#pragma mark NSURLConnectionDataDelegate

- (void)fetchEPG:(NLTEPGResponseBlock)responseBlock withCacheDuration:(int)cacheDuration{
    if([self.cache count] == 0){
        NSLog(@"False EPG cache (should not occur)");
    }
    if(self.cache&&[[NSDate date] compare:self.cacheValidityEnd]==NSOrderedAscending){
        if(responseBlock){
            responseBlock(self.cache,nil);
        }
    }else{
        NSString* urlStr = @"http://www.nolife-tv.com/noair/noair.xml";
        self.cacheValidityEnd = [[NSDate date] dateByAddingTimeInterval:cacheDuration];
        self.cache = nil;
        NSURLRequest* request = [NSURLRequest requestWithURL:[NSURL URLWithString:urlStr]];
        self.connection = [NSURLConnection connectionWithRequest:request delegate:self];
        if(self.connection){
            if(self.responseBlock){
                NSError* error = [NSError errorWithDomain:@"NLTEPGDomain" code:500 userInfo:@{@"message":@"Another call cancelled this one"}];
                self.responseBlock(nil, error);
            }
            self.responseBlock = responseBlock;
#ifdef DEBUG
            NSLog(@"Connecting to %@",urlStr);
#endif
            [self.connection start];
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
        self.parser = [[NSXMLParser alloc] initWithData:self.data];
        self.parser.delegate = self;
        self.parserError = nil;
        self.cache = [NSMutableArray array];
        [self.parser parse];
        
        
        if(self.parserError){
            self.cache = nil;
            if(self.responseBlock){
                self.responseBlock(nil, self.parserError);
                self.responseBlock = nil;
                self.parserError = nil;
            }
        }else{
            if(self.responseBlock){
                NSError* error = nil;
                if(!self.cache){
                    error = [NSError errorWithDomain:@"NLTEPGDomain" code:520 userInfo:@{@"message":@"Unknown parse error"}];
                }
                self.responseBlock(self.cache, error);
                self.responseBlock = nil;
            }
        }
    }

}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error{
    self.cache = nil;
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
        [self.cache addObject:attributeDict];
    }
}

- (void)parser:(NSXMLParser *)parser parseErrorOccurred:(NSError *)parseError{
    self.parserError = parseError;
}

- (NSArray*)cachedEPG{
    if(self.cache){
        return self.cache;
    }else{
        return [NSArray array];
    }
}
@end
