//  WhiteRaccoon
//
//  Created by Valentin Radu on 8/23/11.
//  Copyright 2011 Valentin Radu. All rights reserved.

//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.



#ifdef DEBUG
#	define InfoLog(fmt, ...) NSLog((@"%s [Line %d] " fmt), __PRETTY_FUNCTION__, __LINE__, ##__VA_ARGS__);
#else
#	define InfoLog(...)
#endif


#import <Foundation/Foundation.h>
#import <CFNetwork/CFNetwork.h>

@class WRRequest;
@class WRRequestQueue;
@class WRRequestError;
@class WRRequestListDirectory;

/*======================================================Global Constants, Variables, Structs and Enums============================================================*/


typedef enum {
    kWRFTP
} WRSchemes;


typedef NS_ENUM(long) {
    kWRDefaultBufferSize = 32768
} WRBufferSizes;


typedef enum {
    kWRDefaultTimeout = 30
} WRTimeouts;




/*======================================================WRStreamInfo============================================================*/

@interface WRStreamInfo:NSObject
    @property (nonatomic, strong) NSOutputStream    *writeStream;
    @property (nonatomic, strong) NSInputStream     *readStream;
    @property (nonatomic, assign) long              bytesConsumedThisIteration;
    @property (nonatomic, assign) UInt32            bytesConsumedInTotal;
    @property (nonatomic, assign) SInt64            size;
    @property (nonatomic, assign) UInt8            *buffer;

@end




/*======================================================WRQueueDelegate============================================================*/

@protocol WRQueueDelegate

@required
-(void) queueCompleted:(WRRequestQueue *)queue;


@end






/*======================================================WRBase============================================================*/
//Abstract class, do not instantiate
@interface WRBase : NSObject {
@protected 
    NSString * path;
    NSString * hostname;
}

@property (nonatomic, strong) NSString * username;
@property (nonatomic, assign) WRSchemes schemeId;
@property (weak, nonatomic, readonly) NSString * scheme;
@property (nonatomic, strong) NSString * password;
@property (nonatomic, strong) NSString * hostname;
@property (weak, nonatomic, readonly) NSString * credentials;
@property (weak, nonatomic, readonly) NSURL * fullURL;
@property (nonatomic, strong) NSString * path;
@property (nonatomic, assign) BOOL passive;
@property (nonatomic, strong) WRRequestError * error;

-(void) start;
-(void) destroy;

+(NSDictionary *) cachedFolders;
+(void) addFoldersToCache:(NSArray *) foldersArray forParentFolderPath:(NSString *) key;

@end









/*======================================================WRRequest============================================================*/

@interface WRRequest : WRBase {
    
}

@property (nonatomic, strong) WRRequest * nextRequest;
@property (nonatomic, strong) WRRequest * prevRequest;
@property (nonatomic, copy) void (^completion)(BOOL success);
@property (strong, nonatomic, readonly) WRStreamInfo * streamInfo;
@property (nonatomic, assign) BOOL didManagedToOpenStream;

@end









/*======================================================WRRequestDownload============================================================*/

@interface WRRequestDownload : WRRequest<NSStreamDelegate> {
  
}

@property (nonatomic, strong) NSURL * receivedFile;
@property (nonatomic, strong) NSOutputStream * outputStream;
@property (nonatomic, copy) void (^progress)(long bytesReaden);

@end










/*======================================================WRRequestUpload============================================================*/

@interface WRRequestUpload : WRRequest<NSStreamDelegate> {
    
}

@property (nonatomic, strong) WRRequestListDirectory * listrequest;
@property (nonatomic, strong) NSInputStream * dataStream;

@end










/*======================================================WRRequestDelete============================================================*/

@interface WRRequestDelete : WRRequest<NSStreamDelegate> {
    BOOL isDirectory;
}

@end









/*======================================================WRRequestCreateDirectory============================================================*/

@interface WRRequestCreateDirectory : WRRequestUpload<NSStreamDelegate> {
    
}

@end










/*======================================================WRRequestListDir============================================================*/

@interface WRRequestListDirectory : WRRequestDownload<NSStreamDelegate> {
   
}

@property (nonatomic, strong) NSArray * filesInfo;


@end


typedef NS_ENUM(int32_t) {
    //client errors
    kWRFTPClientHostnameIsNil = 901,
    kWRFTPClientCantOpenStream = 902,
    kWRFTPClientCantWriteStream = 903,
    kWRFTPClientCantReadStream = 904,
    kWRFTPClientFileAlreadyExists = 907,
    kWRFTPClientCantOverwriteDirectory = 908,
    kWRFTPClientStreamTimedOut = 909,
    
    // 400 FTP errors
    kWRFTPServerAbortedTransfer = 426,
    kWRFTPServerResourceBusy = 450,
    kWRFTPServerCantOpenDataConnection = 425,
    
    // 500 FTP errors
    kWRFTPServerUserNotLoggedIn = 530,
    kWRFTPServerFileNotAvailable = 550,
    kWRFTPServerStorageAllocationExceeded = 552,
    kWRFTPServerIllegalFileName = 553,
    kWRFTPServerUnknownError
    
} WRErrorCodes;




/*======================================================WRRequestError============================================================*/

@interface WRRequestError : NSObject {
    
}

@property (weak, nonatomic, readonly) NSError * nserror;
@property (nonatomic, assign) WRErrorCodes errorCode;
@property (weak, nonatomic, readonly) NSString * message;

-(WRErrorCodes) errorCodeWithError:(NSError *) error;
@end

NSString * escapeJavaScript(NSString * source);
