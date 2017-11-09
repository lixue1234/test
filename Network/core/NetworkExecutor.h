//
//  NetworkExecutor.h
//  Pods
//
//  Created by Jaffer on 17/1/11.
//
//

#import <Foundation/Foundation.h>
#import "Requests.h"
#import "AFNetworking.h"


@interface NetworkExecutor : NSObject

@property (nonatomic, strong) AFHTTPSessionManager *sessionManager;

- (instancetype)initWithNetworkCofig:(NetworkConfig *)config;

- (RequestId)executeUnitRequest:(UnitRequest *)request
                     completion:(UnitRequestFinishedBlock)completionBlock;

@end



@interface NetworkExecutor (Serializer)
    
@property (nonatomic, strong) AFJSONRequestSerializer *jsonRequestSerializer;
@property (nonatomic, strong) AFPropertyListRequestSerializer *plistRequestSerializer;
@property (nonatomic, strong) AFJSONResponseSerializer *jsonResponseSerializer;
@property (nonatomic, strong) AFPropertyListResponseSerializer *plistResponseSerializer;
@property (nonatomic, strong) AFXMLParserResponseSerializer *xmlResponseSerializer;

@end


@interface NetworkExecutor (Deliver)
    
- (RequestId)deliverNormalRequestTask:(UnitRequest *)normalRequest
                           completion:(UnitRequestFinishedBlock)completionBlock;
    
- (RequestId)deliverUploadRequestTask:(UnitRequest *)uploadRequest
                           completion:(UnitRequestFinishedBlock)completionBlock;
    
- (RequestId)deliverDownloadRequestTask:(UnitRequest *)downloadRequest
                             completion:(UnitRequestFinishedBlock)completionBlock;
    
@end


@interface NSMutableURLRequest (Additions)
    
- (void)addHttpHeaders:(NSDictionary *)headers;
    
@end


@interface NSURLSessionTask (Additions)
    
@property (nonatomic, strong) UnitRequest *rawRequest;
    
@end


@interface NSDictionary (Additions)

- (NSString *)toJsonString;

@end


@interface NSArray (Additions)

- (NSString *)toJsonString;

@end

