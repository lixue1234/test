//
//  Requests.h
//  Pods
//
//  Created by Jaffer on 17/1/11.
//
//

#import <Foundation/Foundation.h>
#import "NetworkConfig.h"


@class UploadMultipartData;


@interface BaseRequest : NSObject

+ (instancetype)request;

@property (nonatomic, assign) BOOL isCallbackOnMainThread;

@end



@interface UnitRequest : BaseRequest

@property (nonatomic, strong) NSString *url;//完整的接口地址
@property (nonatomic, strong) NSString *path;//相对接口地址

@property (nonatomic, strong) NSDictionary *exclusiveParams;//unique params
@property (nonatomic, strong) NSDictionary *exclusiveHeaders;//unique headers

@property (nonatomic, assign) BOOL needAppendGlobalServerHost;
@property (nonatomic, assign) BOOL needAppendGlobalParams;
@property (nonatomic, assign) BOOL needAppendGlobalHeaders;

@property (nonatomic, assign) RequestId requestId;

@property (nonatomic, assign) RequestTaskType requestTaskType;
@property (nonatomic, assign) RequestMethodType requestMethodType;
@property (nonatomic, assign) RequestSerializeType requestSerializerType;
@property (nonatomic, assign) ResponseSerializeType responseSerializerType;

@property (nonatomic, copy) UnitRequestSuccessBlock unitSuccessBlock;
@property (nonatomic, copy) UnitRequestFailureBlock unitFailureBlock;
@property (nonatomic, copy) UnitRequestCancelBlock unitCancelBlock;
@property (nonatomic, copy) UnitRequestFinishedBlock unitFinishedBlock;
@property (nonatomic, copy) UnitRequestProcessBlock unitProcessBlock;

@property (nonatomic, assign) NSInteger retryTimes; //default 0

@property (nonatomic, strong) NSArray <UploadMultipartData *> *uploadMultipartArray;

@property (nonatomic, strong) NSString *downloadFileSavePath;

@end




@interface GroupRequest : BaseRequest

@property (nonatomic, copy) GroupRequestSuccessBlock groupSuccessBlock;
@property (nonatomic, copy) GroupRequestFailureBlock groupFailureBlock;
@property (nonatomic, copy) GroupRequestFinishedBlock groupFinishedBlock;
@property (nonatomic, strong, readonly) NSArray *unitRequestsArray;
@property (nonatomic, strong, readonly) NSArray *unitResponsesArray;

@end




@interface BatchRequest : GroupRequest

@property (nonatomic, assign) BOOL errorExists;

- (void)addRequests:(UnitRequest *)request, ...;
- (void)addRequestsFromArray:(NSArray <UnitRequest *> *)requestArray;
- (void)finishedUnitRequest:(UnitRequest *)unitRequest resposne:(id)response error:(NSError *)error;

@end





@interface ChainRequest : GroupRequest

- (ChainRequest *)startWithRequest:(UnitRequestConfigBlock)configBlock;
- (ChainRequest *)then:(ChainRequestContinueConfigBlock)continueConfigBlock;
- (UnitRequest *)getNextUnitRequestDependingOnCurrentRequest:(UnitRequest *)request response:(id)respons error:(NSError *)error executeState:(ExecuteState *)state;

@end


typedef NS_ENUM(NSInteger, UploadMultipartAssembleType) {
    UploadMultipartAssembleTypeUndefined = 0,
    
    UploadMultipartAssembleTypeSimpleInfoFromURL,
    UploadMultipartAssembleTypeFullInfoFromURL,
    
    UploadMultipartAssembleTypeSimpleInfoFromData,
    UploadMultipartAssembleTypeFullInfoFromData
};


@interface  UploadMultipartData : NSObject

@property (nonatomic, strong) NSURL *fileURL;
@property (nonatomic, strong) NSString *name;
@property (nonatomic, strong) NSString *fileName;
@property (nonatomic, strong) NSData *fileData;
@property (nonatomic, strong) NSString *mimeType;

+ (instancetype)appendPartWithFileURL:(NSURL *)fileURL
                                 name:(NSString *)name
                             fileName:(NSString *)fileName
                             mimeType:(NSString *)mimeType;

+ (instancetype)appendPartWithFileData:(NSData *)data
                                  name:(NSString *)name
                              fileName:(NSString *)fileName
                              mimeType:(NSString *)mimeType;


@end






