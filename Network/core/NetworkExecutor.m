//
//  NetworkExecutor.m
//  Pods
//
//  Created by Jaffer on 17/1/11.
//
//

#import "NetworkExecutor.h"
#import <objc/runtime.h>

static dispatch_queue_t http_session_manager_completion_callback_queue_create() {
    static dispatch_queue_t completion_callback_queue;
    static dispatch_once_t token;
    dispatch_once(&token, ^{
        completion_callback_queue = dispatch_queue_create("com.jf.session.manager.completion.callback", DISPATCH_QUEUE_CONCURRENT);
    });
    return completion_callback_queue;
}


@interface NetworkExecutor ()

@property (nonatomic, weak) NetworkConfig *config;
@property (nonatomic, strong) NSURLSessionConfiguration *sessionConfig;

@end



@implementation NetworkExecutor

#pragma mark dealloc
- (void)dealloc {
    [self logMsg:^{
        NSLog(@"%s",__func__);
    }];
}

#pragma mark init
- (instancetype)initWithNetworkCofig:(NetworkConfig *)config {
    if (self = [super init]) {
        self.config = config;
    }
    return self;
}

#pragma mark public method
- (RequestId)executeUnitRequest:(UnitRequest *)request
                     completion:(UnitRequestFinishedBlock)completionBlock {
    if (request) {
        switch (request.requestTaskType) {
            case RequestTaskNormal: {
                return [self deliverNormalRequestTask:request
                                           completion:completionBlock];
            }
                break;
            case RequestTaskUpload: {
                return [self deliverUploadRequestTask:request
                                           completion:completionBlock];
            }
                break;
            case RequestTaskDownload: {
                return [self deliverDownloadRequestTask:request
                                             completion:completionBlock];
            }
                break;
            default:
                return [self deliverNormalRequestTask:request
                                           completion:completionBlock];
                break;
        }
    }
    return 0;
}


#pragma mark lazy load
- (AFHTTPSessionManager *)sessionManager {
    if (_sessionManager == nil) {
        _sessionManager = [[AFHTTPSessionManager alloc] initWithBaseURL:nil sessionConfiguration:self.config.sessionConfig];
        _sessionManager.operationQueue.maxConcurrentOperationCount = self.config.maxConcurrentRequestCount;
        _sessionManager.completionQueue = http_session_manager_completion_callback_queue_create();
        _sessionManager.responseSerializer = [AFHTTPResponseSerializer serializer];//需要指定这种类型，不然自己二次校验数据的时候崩溃
    }
    return _sessionManager;
}

#pragma mark tools
- (void)logMsg:(void (^)(void))msg {
    if (self.config.logEnable) {
        if (msg) {
            msg();
        }
    }
}
    
- (NSString *)getRequestMethodName:(UnitRequest *)request {
    NSString *name = @"POST";
    if (request.requestMethodType == RequestMethodGet) {
        name = @"GET";
    }
    return name;
}

- (NSString *)getTaskTypeName:(UnitRequest *)request {
    NSString *name = @"Normal";
    switch (request.requestTaskType) {
        case RequestTaskUpload:
            name = @"Upload";
        break;
        case RequestTaskDownload:
            name = @"Download";
        break;
        default:
            name = @"Normal";
            break;
    }
    return name;
}



@end






@implementation NetworkExecutor (Deliver)

#pragma mark deliver
- (RequestId)deliverNormalRequestTask:(UnitRequest *)normalRequest
                           completion:(UnitRequestFinishedBlock)completionBlock {
    //init request
    AFHTTPRequestSerializer *ser = [self extractRequestSerializer:normalRequest];
    NSError *assembleRequestError = nil;
   
    NSMutableURLRequest *httpRequest = [ser requestWithMethod:[self extractRequestMethod:normalRequest]
                                             URLString:normalRequest.url
                                            parameters:normalRequest.exclusiveParams
                                                 error:&assembleRequestError];
    __weak typeof (self) weakSelf = self;

    if (assembleRequestError) {
        [self logMsg:^{
            __strong typeof (weakSelf) strongSelf = weakSelf;
            NSLog(@"\n\n>>>====Request Start...\nRequest Id = %ld\nRequest Method = %@\nRequest Task = %@\nRequest Url = %@\nRequest Params = %@\nRequest Headers = %@\nRequest Errors = %@\n\n",normalRequest.requestId, [strongSelf getRequestMethodName:normalRequest], [strongSelf getTaskTypeName:normalRequest], normalRequest.url, [self serializeToString:normalRequest.exclusiveParams], httpRequest.allHTTPHeaderFields, assembleRequestError);
        }];

        [self executeCallBack:^{
            Block_Call(completionBlock, nil, assembleRequestError);
        }];
        return 0;
    }
    
    [self setupHttpRequestSettings:httpRequest fromRawRequest:normalRequest];
    
    //init task
    NSURLSessionDataTask *dataTask = nil;
    dataTask = [self.sessionManager dataTaskWithRequest:httpRequest
                                      completionHandler:^(NSURLResponse * _Nonnull response, id  _Nullable responseObject, NSError * _Nullable error) {
                                          __strong typeof (weakSelf) strongSelf = weakSelf;
                                          
                                          
                                          [strongSelf dealWithHttpResponse:response
                                                                data:responseObject
                                                               error:error
                                                          completion:completionBlock
                                                          rawRequest:normalRequest];
                           }];
    
    //bind
    normalRequest.requestId = dataTask.taskIdentifier;
    dataTask.rawRequest = normalRequest;
    
    //start
    [dataTask resume];
    
    [self logMsg:^{
        __strong typeof (weakSelf) strongSelf = weakSelf;
        NSLog(@"\n\n>>>====Request Start...\nRequest Id = %ld\nRequest Method = %@\nRequest Task = %@\nRequest Url = %@\nRequest Params = %@\nRequest Headers = %@\n\n",normalRequest.requestId, [strongSelf getRequestMethodName:normalRequest], [strongSelf getTaskTypeName:normalRequest], normalRequest.url, [self serializeToString:normalRequest.exclusiveParams], httpRequest.allHTTPHeaderFields);
    }];
    
    return dataTask.taskIdentifier;
}


- (RequestId)deliverUploadRequestTask:(UnitRequest *)uploadRequest
                           completion:(UnitRequestFinishedBlock)completionBlock {
    //init request
    AFHTTPRequestSerializer *ser = [self extractRequestSerializer:uploadRequest];
    NSError *assembleRequestError = nil;
    
    NSMutableURLRequest *httpRequest = nil;
    
    __weak typeof (self) weakSelf = self;
    httpRequest = [ser multipartFormRequestWithMethod:[self extractRequestMethod:uploadRequest]
                                            URLString:uploadRequest.url
                                           parameters:uploadRequest.exclusiveParams
                            constructingBodyWithBlock:^(id<AFMultipartFormData>  _Nonnull formData) {
                                __strong typeof (weakSelf) strongSelf = weakSelf;
                                if (uploadRequest.uploadMultipartArray && uploadRequest.uploadMultipartArray.count > 0) {
                                    [strongSelf appendUploadDatas:uploadRequest.uploadMultipartArray intoMultipartContainer:formData];
                                }
                            }
                                                error:&assembleRequestError];
    
    if (assembleRequestError) {
        [self logMsg:^{
            __strong typeof (weakSelf) strongSelf = weakSelf;
            NSLog(@"\n\n>>>====Request Start...\nRequest Id = %ld\nRequest Method = %@\nRequest Task = %@\nRequest Url = %@\nRequest Params = %@\nRequest Headers = %@\nRequest Errors = %@\n\n",uploadRequest.requestId, [strongSelf getRequestMethodName:uploadRequest], [strongSelf getTaskTypeName:uploadRequest], uploadRequest.url, [self serializeToString:uploadRequest.exclusiveParams], httpRequest.allHTTPHeaderFields, assembleRequestError);
        }];

        [self executeCallBack:^{
            Block_Call(completionBlock, nil, assembleRequestError);
        }];
        return 0;
    }
    
    [self setupHttpRequestSettings:httpRequest fromRawRequest:uploadRequest];
    
    //init task
    NSURLSessionUploadTask *uploadTask = nil;
    uploadTask = [self.sessionManager uploadTaskWithStreamedRequest:httpRequest
                                                           progress:uploadRequest.unitProcessBlock
                                                  completionHandler:^(NSURLResponse * _Nonnull response, id  _Nullable responseObject, NSError * _Nullable error) {
                                                      __strong typeof (weakSelf) strongSelf = weakSelf;
                                                      [strongSelf dealWithHttpResponse:response
                                                                            data:responseObject
                                                                           error:error
                                                                      completion:completionBlock
                                                                      rawRequest:uploadRequest];
                                                  }];
  
    //bind
    uploadRequest.requestId = uploadTask.taskIdentifier;
    uploadTask.rawRequest = uploadRequest;
    
    //start
    [uploadTask resume];
    
    [self logMsg:^{
        __strong typeof (weakSelf) strongSelf = weakSelf;
        NSLog(@"\n\n>>>====Request Start...\nRequest Id = %ld\nRequest Method = %@\nRequest Task = %@\nRequest Url = %@\nRequest Params = %@\nRequest Headers = %@\n\n",uploadRequest.requestId, [strongSelf getRequestMethodName:uploadRequest], [strongSelf getTaskTypeName:uploadRequest], uploadRequest.url, [self serializeToString:uploadRequest.exclusiveParams], httpRequest.allHTTPHeaderFields);
    }];
    
    return uploadTask.taskIdentifier;
}

- (RequestId)deliverDownloadRequestTask:(UnitRequest *)downloadRequest
                             completion:(UnitRequestFinishedBlock)completionBlock {
    //init request
    AFHTTPRequestSerializer *ser = [self extractRequestSerializer:downloadRequest];
    NSError *assembleRequestError = nil;
    
    NSMutableURLRequest *httpRequest = [ser requestWithMethod:[self extractRequestMethod:downloadRequest]
                                                    URLString:downloadRequest.url
                                                   parameters:downloadRequest.exclusiveParams
                                                        error:&assembleRequestError];
    __weak typeof (self) weakSelf = self;

    if (assembleRequestError) {
        [self logMsg:^{
            __strong typeof (weakSelf) strongSelf = weakSelf;
            NSLog(@"\n\n>>>====Request Start...\nRequest Id = %ld\nRequest Method = %@\nRequest Task = %@\nRequest Url = %@\nRequest Params = %@\nRequest Headers = %@\nRequest Errors = %@\n\n",downloadRequest.requestId, [strongSelf getRequestMethodName:downloadRequest], [strongSelf getTaskTypeName:downloadRequest], downloadRequest.url, [self serializeToString:downloadRequest.exclusiveParams], httpRequest.allHTTPHeaderFields, assembleRequestError);
        }];

        [self executeCallBack:^{
            Block_Call(completionBlock, nil, assembleRequestError);
        }];
        return 0;
    }
    
    [self setupHttpRequestSettings:httpRequest fromRawRequest:downloadRequest];
    
    //init task
    NSURLSessionDownloadTask *downloadTask = nil;
    downloadTask = [self.sessionManager downloadTaskWithRequest:httpRequest
                                                       progress:downloadRequest.unitProcessBlock
                                                    destination:^NSURL * _Nonnull(NSURL * _Nonnull targetPath, NSURLResponse * _Nonnull response) {
                                                        NSURL *saveURL = nil;
                                                        if (downloadRequest.downloadFileSavePath) {
                                                            saveURL = [NSURL fileURLWithPath:downloadRequest.downloadFileSavePath];
                                                        } else {
                                                            NSAssert(NO, @"there is no download path for the download task");
                                                        }
                                                        return saveURL;
                                                    }
                                              completionHandler:^(NSURLResponse * _Nonnull response, NSURL * _Nullable filePath, NSError * _Nullable error) {
                                                  __strong typeof(weakSelf) strongSelf = weakSelf;
                                                  [strongSelf dealWithHttpResponse:response
                                                                            data:filePath
                                                                           error:error
                                                                      completion:completionBlock
                                                                      rawRequest:downloadRequest];
                                              }];
    
    //bind
    downloadRequest.requestId = downloadTask.taskIdentifier;
    downloadTask.rawRequest = downloadRequest;
    
    //start
    [downloadTask resume];
    
    [self logMsg:^{
        __strong typeof (weakSelf) strongSelf = weakSelf;
        NSLog(@"\n\n>>>====Request Start...\nRequest Id = %ld\nRequest Method = %@\nRequest Task = %@\nRequest Url = %@\nRequest Params = %@\nRequest Headers = %@\n\n",downloadRequest.requestId, [strongSelf getRequestMethodName:downloadRequest], [strongSelf getTaskTypeName:downloadRequest], downloadRequest.url, [self serializeToString:downloadRequest.exclusiveParams], httpRequest.allHTTPHeaderFields);
    }];

    
    return downloadTask.taskIdentifier;
}

#pragma mark data process
- (void)dealWithHttpResponse:(NSURLResponse *)response
                        data:(id)responseData
                       error:(NSError *)error
                  completion:(UnitRequestFinishedBlock)completionBlock
                  rawRequest:(UnitRequest *)rawRequest {

    __weak typeof(self) weakSelf = self;

    
    if (error) {
        [self logMsg:^{
            __strong typeof (weakSelf) strongSelf = weakSelf;
            NSLog(@"\n\n>>>====Request Finished...\nRequest Id = %ld\nRequest Method = %@\nRequest Task = %@\nRequest Url = %@\nRequest Params = %@\nRequest Response = %@\nRequest Errors = %@\n\n",rawRequest.requestId, [strongSelf getRequestMethodName:rawRequest], [strongSelf getTaskTypeName:rawRequest], rawRequest.url, [self serializeToString:rawRequest.exclusiveParams], nil, error);
        }];

        [self executeCallBack:^{
            Block_Call(completionBlock, nil, error);
        }];
    } else {
        RequestTaskType taskType = rawRequest.requestTaskType;
        
        if (taskType == RequestTaskDownload) {
            [self logMsg:^{
                __strong typeof (weakSelf) strongSelf = weakSelf;
                NSLog(@"\n\n\n>>>====Request Finished...\nRequest Id = %ld\nRequest Method = %@\nRequest Task = %@\nRequest Url = %@\nRequest Params = %@\nRequest Response = %@\nRequest Errors = %@\n\n",rawRequest.requestId, [strongSelf getRequestMethodName:rawRequest], [strongSelf getTaskTypeName:rawRequest], rawRequest.url, [self serializeToString:rawRequest.exclusiveParams], [self serializeToString:responseData], nil);
            }];

            [self executeCallBack:^{
                Block_Call(completionBlock, responseData, nil);
            }];
        } else {
            AFHTTPResponseSerializer *ser = [self extractResponseSerializer:rawRequest];
            NSError *serializeError = nil;
            
            id responseObj = [ser responseObjectForResponse:response
                                                       data:responseData
                                                      error:&serializeError];
            
            [self logMsg:^{
                __strong typeof (weakSelf) strongSelf = weakSelf;
                NSLog(@"\n\n>>>====Request Finished...\nRequest Id = %ld\nRequest Method = %@\nRequest Task = %@\nRequest Url = %@\nRequest Params = %@\nRequest Response = %@\nRequest Errors = %@\n\n",rawRequest.requestId, [strongSelf getRequestMethodName:rawRequest], [strongSelf getTaskTypeName:rawRequest], rawRequest.url, [self serializeToString:rawRequest.exclusiveParams], [self serializeToString:responseObj], serializeError);
            }];

            if (serializeError) {
                [self executeCallBack:^{
                    Block_Call(completionBlock, nil, responseObj);
                }];
            } else {
                [self executeCallBack:^{
                    Block_Call(completionBlock, responseObj, nil);
                }];
            }
        }
        
     }
}

#pragma mark tools
- (NSString *)serializeToString:(id)object {
    NSString *str = nil;
    
    if (object) {
        if ([object isKindOfClass:[NSDictionary class]] || [object isKindOfClass:[NSArray class]]) {
            str = [object toJsonString];
        } else {
            str = [object description];
        }
    }
    
    return str;
}

- (void)appendUploadDatas:(NSArray <UploadMultipartData *> *)dataParts intoMultipartContainer:(id <AFMultipartFormData>)formData {
    if (dataParts && dataParts.count > 0) {
        for (UploadMultipartData *partData in dataParts) {
            if (partData.name) {
                if (partData.fileData) {
                    if (partData.fileName && partData.mimeType) {
                        [formData appendPartWithFileData:partData.fileData
                                                    name:partData.name
                                                fileName:partData.fileName
                                                mimeType:partData.mimeType];
                    } else {
                        [formData appendPartWithFormData:partData.fileData
                                                    name:partData.name];
                    }
                } else if (partData.fileURL) {
                    if (partData.fileName && partData.mimeType) {
                        NSError *appendError = nil;
                        [formData appendPartWithFileURL:partData.fileURL
                                                   name:partData.name
                                               fileName:partData.fileName
                                               mimeType:partData.mimeType
                                                  error:&appendError];
                        if (appendError) {
                            NSLog(@"upload data name===%@ form file==%@,error occured!==%@", partData.name,partData.fileURL, appendError);
                        }
                    } else {
                        NSError *appendError = nil;
                        [formData appendPartWithFileURL:partData.fileURL
                                                   name:partData.name
                                                  error:&appendError];
                        if (appendError) {
                            NSLog(@"upload data name===%@ form file==%@,error occured!==%@", partData.name,partData.fileURL, appendError);
                        }
                    }
                }
            } else {
                NSLog(@"upload part data is invalid cause no name");
            }
        }
    }
}

- (void)executeCallBack:(void(^)(void))block {
    dispatch_async(self.sessionManager.completionQueue, ^{
        block();
    });
}

- (void)setupHttpRequestSettings:(NSMutableURLRequest *)httpRequest fromRawRequest:(UnitRequest *)rawRequest {
    //http headers
    if (rawRequest.exclusiveHeaders && rawRequest.exclusiveHeaders.count > 0) {
        [httpRequest addHttpHeaders:rawRequest.exclusiveHeaders];
    }
}

- (AFHTTPRequestSerializer *)extractRequestSerializer:(UnitRequest *)request {
    switch (request.requestSerializerType) {
        case RequestSerializeRAW:
            return self.sessionManager.requestSerializer;
            break;
        case RequestSerializeJSON:
            return self.jsonRequestSerializer;
            break;
        case RequestSerializePlist:
            return self.plistRequestSerializer;
            break;
        default:
            return self.sessionManager.requestSerializer;
            break;
    }
}

- (AFHTTPResponseSerializer *)extractResponseSerializer:(UnitRequest *)request {
    switch (request.responseSerializerType) {
        case ResponseSerializeRAW:
            return self.sessionManager.responseSerializer;
            break;
        case ResponseSerializeJSON:
            return self.jsonResponseSerializer;
            break;
        case ResponseSerializePlist:
            return self.plistResponseSerializer;
            break;
        case ResponseSerializeXML:
            return self.xmlResponseSerializer;
            break;
        default:
            return self.sessionManager.responseSerializer;
            break;
    }
}

- (NSString *)extractRequestMethod:(UnitRequest *)request {
    NSString *requestMethod = nil;
    switch (request.requestMethodType) {
        case RequestMethodGet:
            requestMethod = @"GET";
            break;
        case RequestMethodPost:
            requestMethod = @"POST";
        default:
            requestMethod = @"POST";
            break;
    }
    return requestMethod;
}

@end






@implementation  NetworkExecutor (Serializer)

#pragma mark request serializer

- (void)setJsonRequestSerializer:(AFJSONRequestSerializer *)jsonRequestSerializer {
    objc_setAssociatedObject(self, _cmd, jsonRequestSerializer, OBJC_ASSOCIATION_RETAIN);
}

- (AFJSONRequestSerializer *)jsonRequestSerializer {
    AFJSONRequestSerializer *ser = objc_getAssociatedObject(self, @selector(setJsonResponseSerializer:));
    if (ser == nil) {
        ser = [AFJSONRequestSerializer serializer];
        self.jsonRequestSerializer = ser;
    }
    return ser;
}

- (void)setPlistRequestSerializer:(AFPropertyListRequestSerializer *)plistRequestSerializer {
    objc_setAssociatedObject(self, _cmd, plistRequestSerializer, OBJC_ASSOCIATION_RETAIN);
}

- (AFPropertyListRequestSerializer *)plistRequestSerializer {
    AFPropertyListRequestSerializer *ser = objc_getAssociatedObject(self, @selector(setPlistResponseSerializer:));
    if (ser == nil) {
        ser = [AFPropertyListRequestSerializer serializer];
        self.plistRequestSerializer = ser;
    }
    return ser;
}

#pragma mark response serializer

- (void)setJsonResponseSerializer:(AFJSONResponseSerializer *)jsonResponseSerializer {
    objc_setAssociatedObject(self, _cmd, jsonResponseSerializer, OBJC_ASSOCIATION_RETAIN);
}

- (AFJSONResponseSerializer *)jsonResponseSerializer {
    AFJSONResponseSerializer *ser = objc_getAssociatedObject(self, @selector(setJsonResponseSerializer:));
    if (ser == nil) {
        ser = [AFJSONResponseSerializer serializer];
        ser.acceptableContentTypes = [NSSet setWithObjects:@"application/json", @"text/json", @"text/javascript",@"text/html", nil];
        self.jsonResponseSerializer = ser;
    }
    return ser;
}

- (void)setPlistResponseSerializer:(AFPropertyListResponseSerializer *)plistResponseSerializer {
    objc_setAssociatedObject(self, _cmd, plistResponseSerializer, OBJC_ASSOCIATION_RETAIN);
}

- (AFPropertyListResponseSerializer *)plistResponseSerializer {
    AFPropertyListResponseSerializer *ser = objc_getAssociatedObject(self, @selector(setPlistResponseSerializer:));
    if (ser == nil) {
        ser = [AFPropertyListResponseSerializer serializer];
        self.plistResponseSerializer = ser;
    }
    return ser;
}

- (void)setXmlResponseSerializer:(AFXMLParserResponseSerializer *)xmlResponseSerializer {
    objc_setAssociatedObject(self, _cmd, xmlResponseSerializer, OBJC_ASSOCIATION_RETAIN);
}

- (AFXMLParserResponseSerializer *)xmlResponseSerializer {
    AFXMLParserResponseSerializer *ser = objc_getAssociatedObject(self, @selector(setXmlResponseSerializer:));
    if (ser == nil) {
        ser = [AFXMLParserResponseSerializer serializer];
        self.xmlResponseSerializer = ser;
    }
    return ser;
}


@end



@implementation NSMutableURLRequest (Additions)

- (void)addHttpHeaders:(NSDictionary *)headers {
    if (headers && headers.count > 0) {
        [headers enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
            [self setValue:obj forHTTPHeaderField:key];
        }];
    }
}

@end


@implementation NSURLSessionTask (Additions)

- (void)setRawRequest:(UnitRequest *)rawRequest {
    objc_setAssociatedObject(self, _cmd, rawRequest, OBJC_ASSOCIATION_RETAIN);
}

- (UnitRequest *)rawRequest {
    return objc_getAssociatedObject(self, @selector(setRawRequest:));
}

@end


@implementation NSDictionary (Additions)

- (NSString *)toJsonString {
    NSString *jsonString = nil;
    NSError *jsonError = nil;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:self options:0 error:&jsonError];
    
    if (jsonError) {
        NSLog(@"%s::json error==%@",__func__, jsonError);
        return nil;
    }
    
    jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    
    return jsonString;
}


@end


@implementation NSArray (Additions)

- (NSString *)toJsonString {
    NSString *jsonString = nil;
    NSError *jsonError = nil;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:self options:0 error:&jsonError];
    
    if (jsonError) {
        NSLog(@"%s::json error==%@",__func__, jsonError);
        return nil;
    }
    
    jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    
    return jsonString;
}

@end



