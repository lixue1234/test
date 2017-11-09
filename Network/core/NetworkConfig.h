//
//  NetworkConfig.h
//  Pods
//
//  Created by Jaffer on 17/1/11.
//
//

#import <Foundation/Foundation.h>

@class UnitRequest;
@class BatchRequest;
@class ChainRequest;
@class NetworkConfig;

#define Block_Call(block, ...) ({!block ? nil : block(__VA_ARGS__);})

typedef NSInteger RequestId;

//config
typedef void (^NetworkDispatcherConfigBlock) (NetworkConfig *config);
typedef void (^UnitRequestConfigBlock) (UnitRequest *request);
typedef void (^BatchRequestConfigBlock) (BatchRequest *request);
typedef void (^ChainRequestConfigBlock) (ChainRequest *request);
typedef void (^ChainRequestContinueConfigBlock) (UnitRequest *dependingConfigRequest, id formerResponse, BOOL *stop);

//unit request
typedef void (^UnitRequestProcessBlock) (NSProgress *progress);
typedef void (^UnitRequestSuccessBlock) (id responseData);
typedef void (^UnitRequestFailureBlock) (NSError *error);
typedef void (^UnitRequestFinishedBlock) (id responseData, NSError *error);
typedef void (^UnitRequestCancelBlock) (UnitRequest *request);

//group request
typedef void (^GroupRequestSuccessBlock) (NSArray *responseDatas);
typedef void (^GroupRequestFailureBlock) (NSArray *errors);
typedef void (^GroupRequestFinishedBlock) (NSArray *successDatas, NSArray *mixedResponseDatas);


typedef NS_ENUM(NSInteger, ExecuteState) {
    ExecuteStateUndefined = 0,
    ExecuteStateSuccss,
    ExecuteStateFialure
};

typedef NS_ENUM(NSInteger, RequestTaskType) {
    RequestTaskNormal = 0,
    RequestTaskUpload,
    RequestTaskDownload
};

typedef NS_ENUM(NSInteger, RequestMethodType) {
    RequestMethodPost = 0,
    RequestMethodGet
};

typedef NS_ENUM(NSInteger, RequestSerializeType) {
    //!< Encodes parameters to a query string and put it into HTTP body, setting the `Content-Type` of the encoded request to default value `application/x-www-form-urlencoded`.
    RequestSerializeRAW = 0,
    
    //!< Encodes parameters as JSON using `NSJSONSerialization`, setting the `Content-Type` of the encoded request to `application/json`.
    RequestSerializeJSON,
    
    //!< Encodes parameters as Property List using `NSPropertyListSerialization`, setting the `Content-Type` of the encoded request to `application/x-plist`.
    RequestSerializePlist
};


typedef NS_ENUM(NSInteger, ResponseSerializeType) {
    //!< Validates the response status code and content type, and returns the default response data.
    ResponseSerializeRAW = 0,

    //!< Validates and decodes JSON responses using `NSJSONSerialization`, and returns a NSDictionary/NSArray/... JSON object.
    ResponseSerializeJSON,
   
    //!< Validates and decodes Property List responses using `NSPropertyListSerialization`, and returns a property list object.
    ResponseSerializePlist,
    
    //!< Validates and decodes XML responses as an `NSXMLParser` objects.
    ResponseSerializeXML
};


@interface NetworkConfig : NSObject

@property (nonatomic, strong) NSString *serverHost;
@property (nonatomic, strong) NSDictionary *publicParams;
@property (nonatomic, strong) NSDictionary *publicHeaders;
@property (nonatomic, strong) NSURLSessionConfiguration *sessionConfig;
@property (nonatomic, strong) dispatch_queue_t callbackQueue;
@property (nonatomic, assign) NSInteger maxConcurrentRequestCount;
@property (nonatomic, assign) BOOL logEnable;

@end


















