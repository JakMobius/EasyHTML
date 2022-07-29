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

#import "WhiteRaccoon.h"
#pragma GCC diagnostic ignored "-Wdeprecated"


/*======================================================WRStreamInfo============================================================*/


@implementation WRStreamInfo
@synthesize buffer, bytesConsumedInTotal, bytesConsumedThisIteration, readStream, size, writeStream;

@end



/*======================================================WRBase============================================================*/

@implementation WRBase
@synthesize passive, password, username, schemeId, error;



static NSMutableDictionary *folders;

+ (void)initialize
{    
    static BOOL isCacheInitalized = NO;
    if(!isCacheInitalized)
    {
        isCacheInitalized = YES;
        folders = [[NSMutableDictionary alloc] init];
    }
}


+(NSDictionary *) cachedFolders {
    return folders;
}

+(void) addFoldersToCache:(NSArray *) foldersArray forParentFolderPath:(NSString *) key {
    [folders setObject:foldersArray forKey:key];
}


- (id)init {
    self = [super init];
    if (self) {
        self.schemeId = kWRFTP;
        self.passive = NO;
        self.password = nil;
        self.username = nil;
        self.hostname = nil;
        self.path = @"";
    }
    return self;
}

-(NSURL*) fullURL {
    // first we merge all the url parts into one big and beautiful url
    NSString * fullURLString = [self.scheme stringByAppendingFormat:@"%@%@%@%@", @"://", self.credentials, self.hostname, self.path];
    
    fullURLString = [fullURLString stringByAddingPercentEncodingWithAllowedCharacters:NSCharacterSet.URLQueryAllowedCharacterSet];
    
    return [NSURL URLWithString: fullURLString];
}

-(NSString *)path {
    //  we remove all the extra slashes from the directory path, including the last one (if there is one)
    //  we also escape it
    NSString * escapedPath = [path stringByStandardizingPath];   
    
    
    //  we need the path to be absolute, if it's not, we *make* it
    if (![escapedPath isAbsolutePath]) {
        escapedPath = [@"/" stringByAppendingString:escapedPath];
    }
    
    if([escapedPath  isEqual: @"/"]) {
        escapedPath = @"";
    }
    
    return escapedPath;
}


-(void) setPath:(NSString *)directoryPathLocal {
    path = directoryPathLocal;
}



-(NSString *)scheme {
    switch (self.schemeId) {
        case kWRFTP:
            return @"ftp";
            break;
            
        default:
            InfoLog(@"The scheme id was not recognized! Default FTP set!");
            return @"ftp";
            break;
    }
    
    return @"";
}

-(NSString *) hostname {
    return [hostname stringByStandardizingPath];
}

-(void)setHostname:(NSString *)hostnamelocal {
    hostname = hostnamelocal;
}

-(NSString *) credentials {    
    
    NSString * cred;
    
    if (self.username!=nil) {
        if (self.password!=nil) {
            cred = [NSString stringWithFormat:@"%@:%@@", self.username, self.password];
        }else{
            cred = [NSString stringWithFormat:@"%@@", self.username];
        }
    }else{
        cred = @"";
    }
    
    return [cred stringByStandardizingPath];
}




-(void) start{
}

-(void) destroy{
    
}


@end



/*======================================================WRRequest============================================================*/


@implementation WRRequest
@synthesize nextRequest, prevRequest, streamInfo, didManagedToOpenStream;

- (id)init {
    self = [super init];
    if (self) {
        streamInfo = [[WRStreamInfo alloc] init];
        self.streamInfo.readStream = nil;
        self.streamInfo.writeStream = nil;
        self.streamInfo.bytesConsumedThisIteration = 0;
        self.streamInfo.bytesConsumedInTotal = 0;
        
        free(self.streamInfo.buffer);
        self.streamInfo.buffer = calloc(kWRDefaultBufferSize, sizeof(UInt8));
    }
    return self;
}

-(void)destroy {
    
    self.streamInfo.bytesConsumedThisIteration = 0;
    self.streamInfo.bytesConsumedInTotal = 0;
    [super destroy];
}

-(void)dealloc {
    
    free(streamInfo.buffer);
    
    
}

@end


/*======================================================WRRequestDownload============================================================*/

@implementation WRRequestDownload
@synthesize completion, receivedFile, outputStream;

-(void) start{
    
    assert(hostname != nil);
    
    // a little bit of C because I was not able to make NSInputStream play nice
    CFReadStreamRef readStreamRef = CFReadStreamCreateWithFTPURL(NULL, (__bridge CFURLRef)self.fullURL);
    self.streamInfo.readStream = (NSInputStream *)CFBridgingRelease(readStreamRef);
    
    [self.streamInfo.readStream setProperty:(id)(self.passive ? kCFBooleanTrue : kCFBooleanFalse) forKey:(id)kCFStreamPropertyFTPUsePassiveMode];
    
    if (self.streamInfo.readStream==nil) {
        InfoLog(@"Can't open the read stream! Possibly wrong URL");
        self.error = [[WRRequestError alloc] init];
        self.error.errorCode = kWRFTPClientCantOpenStream;
        if(self.completion) self.completion(false);
        return;
    }
    
    if(!self.receivedFile) {
        
        NSMutableString * fileName = [[NSUUID UUID] UUIDString].mutableCopy;
        
        NSMutableString * path = [NSTemporaryDirectory() stringByAppendingPathComponent:fileName].mutableCopy;
        
        self.receivedFile = [NSURL fileURLWithPath:path];
    }
    
    [NSFileManager.defaultManager createFileAtPath:self.receivedFile.path contents:nil attributes:nil];
    self.outputStream = [NSOutputStream outputStreamToFileAtPath:receivedFile.path
                                                          append:true];
    [self.outputStream setProperty:(id)(self.passive ? kCFBooleanTrue : kCFBooleanFalse) forKey:(id)kCFStreamPropertyFTPUsePassiveMode];
    
    [self.outputStream open];
    
    self.streamInfo.readStream.delegate = self;
	[self.streamInfo.readStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
	[self.streamInfo.readStream open];
    
    self.didManagedToOpenStream = NO;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, kWRDefaultTimeout * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        if (!self.didManagedToOpenStream && self.error==nil) {
            InfoLog(@"No response from the server. Timeout.");
            self.error = [[WRRequestError alloc] init];
            self.error.errorCode = kWRFTPClientStreamTimedOut;
            if(self.completion) self.completion(false);
            [self destroy];
        }
    });
}

//stream delegate
- (void)stream:(NSStream *)theStream handleEvent:(NSStreamEvent)streamEvent {
    
    switch (streamEvent) {
        case NSStreamEventOpenCompleted: {
            self.didManagedToOpenStream = YES;
            self.streamInfo.bytesConsumedInTotal = 0;
        } break;
        case NSStreamEventHasBytesAvailable: {
            
            self.streamInfo.bytesConsumedThisIteration = [self.streamInfo.readStream read:self.streamInfo.buffer maxLength:kWRDefaultBufferSize];
            
            if (self.streamInfo.bytesConsumedThisIteration!=-1) {
                if (self.streamInfo.bytesConsumedThisIteration!=0) {
                    
                    [self.outputStream write: (const uint8_t *) self.streamInfo.buffer maxLength:self.streamInfo.bytesConsumedThisIteration];
                }
                
                self.streamInfo.bytesConsumedInTotal += (UInt32)self.streamInfo.bytesConsumedThisIteration;
                
                if(self.progress) {
                    self.progress(self.streamInfo.bytesConsumedInTotal);
                }
            }else{
                InfoLog(@"Stream opened, but failed while trying to read from it.");
                self.error = [[WRRequestError alloc] init];
                self.error.errorCode = kWRFTPClientCantReadStream;
                if(completion) completion(false);
                [self destroy];
            }
            
        } break;
        case NSStreamEventHasSpaceAvailable: {
            
        } break;
        case NSStreamEventErrorOccurred: {
            self.error = [[WRRequestError alloc] init];
            self.error.errorCode = [self.error errorCodeWithError:[theStream streamError]];
            InfoLog(@"%@", self.error.message);
            if(completion) completion(false);
            [self destroy];
        } break;
            
        case NSStreamEventEndEncountered: {
            if(completion) completion(true);
            [self destroy];
        } break;
            
        case NSStreamEventNone: break;
    }
}

-(void) destroy{
    
    if(self.outputStream) [self.outputStream close];
    
    if (self.streamInfo.readStream) {
        [self.streamInfo.readStream close];
        [self.streamInfo.readStream removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
        self.streamInfo.readStream = nil;
    }
    
    [super destroy];
}


@end


/*======================================================WRRequestDelete============================================================*/

@implementation WRRequestDelete

-(NSString *)path {
    
    NSString * lastCharacter = [path substringFromIndex:[path length] - 1];
    isDirectory = ([lastCharacter isEqualToString:@"/"]);
    
    if (!isDirectory) return [super path];
    
    NSString * directoryPath = [super path];
    if (![directoryPath isEqualToString:@""]) {
        directoryPath = [directoryPath stringByAppendingString:@"/"];
    }
    return directoryPath;
}

-(void) start{
    
    assert(hostname != nil);
    
    __weak typeof(self) weakSelf = self;
    
    dispatch_async(dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        SInt32 errorCode = 0;
        
        BOOL result = CFURLDestroyResource((__bridge CFURLRef)self.fullURL, &errorCode);
        
        if(!weakSelf) {
            return;
        }
        
        weakSelf.error = [[WRRequestError alloc] init];
        weakSelf.error.errorCode = errorCode;
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if(!weakSelf) {
                return;
            }
            
            weakSelf.completion(result);
        });
    });
}

-(void) destroy{
    [super destroy];  
}


@end


/*======================================================WRRequestUpload============================================================*/

@interface WRRequestUpload () //note the empty category name

@end

@implementation WRRequestUpload
@synthesize listrequest, dataStream;



-(void) start {
    assert(self.hostname);
    assert(self.dataStream);
    
    CFWriteStreamRef writeStreamRef = CFWriteStreamCreateWithFTPURL(NULL, (__bridge CFURLRef)self.fullURL);
    self.streamInfo.writeStream = (NSOutputStream *)CFBridgingRelease(writeStreamRef);
    
    [self.streamInfo.writeStream setProperty:(id)(self.passive ? kCFBooleanTrue : kCFBooleanFalse) forKey:(id)kCFStreamPropertyFTPUsePassiveMode];
    
    if (self.streamInfo.writeStream==nil) {
        InfoLog(@"Can't open the write stream! Possibly wrong URL!");
        self.error = [[WRRequestError alloc] init];
        self.error.errorCode = kWRFTPClientCantOpenStream;
        if(self.completion) self.completion(false);
        return;
    }
    
    [dataStream open];
    
    self.streamInfo.writeStream.delegate = self;
    [self.streamInfo.writeStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    [self.streamInfo.writeStream open];
    
    self.didManagedToOpenStream = NO;
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, kWRDefaultTimeout * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        if (!self.didManagedToOpenStream && self.error==nil) {
            InfoLog(@"No response from the server. Timeout.");
            self.error = [[WRRequestError alloc] init];
            self.error.errorCode = kWRFTPClientStreamTimedOut;
            if(self.completion) self.completion(false);
            [self destroy];
        }
    });
}

//stream delegate
- (void)stream:(NSStream *)theStream handleEvent:(NSStreamEvent)streamEvent {
    
    switch (streamEvent) {
        case NSStreamEventOpenCompleted: {
            self.didManagedToOpenStream = YES;
        } break;
        case NSStreamEventHasBytesAvailable: {
            
        } break;
        case NSStreamEventHasSpaceAvailable: {
            
            uint8_t * nextPackage = malloc(kWRDefaultBufferSize);
            
            long length = [dataStream read: nextPackage maxLength:kWRDefaultBufferSize];
            
            self.streamInfo.bytesConsumedThisIteration = [self.streamInfo.writeStream write:nextPackage maxLength:length];
            
            free(nextPackage);
            
            if (length > -1) {
                if(!dataStream.hasBytesAvailable) {
                    if(self.completion) self.completion(true);
                    dataStream = nil;
                    [self destroy];
                }
            }else{
                InfoLog(@"Cannot write to the stream. Upload failed!");
                self.error = [[WRRequestError alloc] init];
                self.error.errorCode = kWRFTPClientCantWriteStream;
                if(self.completion) self.completion(false);
                [self destroy];
            }
            
        } break;
        case NSStreamEventErrorOccurred: {
            self.error = [[WRRequestError alloc] init];
            self.error.errorCode = [self.error errorCodeWithError:[theStream streamError]];
            InfoLog(@"%@", self.error.message);
            if(self.completion) self.completion(false);
            [self destroy];
        } break;
            
        case NSStreamEventEndEncountered: {
            InfoLog(@"The stream was closed by server while we were uploading the data. Upload failed!");
            self.error = [[WRRequestError alloc] init];
            self.error.errorCode = kWRFTPServerAbortedTransfer;
            if(self.completion) self.completion(false);
            [self destroy];
        } break;
            
            
        case NSStreamEventNone:
        {
            ;
        }break;
    }
}

-(void) destroy{
    
    [dataStream close];
    
    if (self.streamInfo.writeStream) {
        
        [self.streamInfo.writeStream close];
        [self.streamInfo.writeStream removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
        self.streamInfo.writeStream = nil;
        
    }
    
    
    [super destroy];
}



@end



/*======================================================WRRequestCreateDirectory============================================================*/

@implementation WRRequestCreateDirectory

-(NSString *)path {
    //  the path will always point to a directory, so we add the final slash to it (if there was one before escaping/standardizing, it's *gone* now)
    NSString * directoryPath = [super path];
    if (![directoryPath isEqualToString:@""]) {
        directoryPath = [directoryPath stringByAppendingString:@"/"];
    }
    return directoryPath;
}

-(void) start {
    assert(self.hostname != nil);
    
    CFWriteStreamRef writeStreamRef = CFWriteStreamCreateWithFTPURL(NULL, (__bridge CFURLRef)self.fullURL);
    self.streamInfo.writeStream = (NSOutputStream *)CFBridgingRelease(writeStreamRef);
    
    [self.streamInfo.writeStream setProperty:(id)(self.passive ? kCFBooleanTrue : kCFBooleanFalse) forKey:(id)kCFStreamPropertyFTPUsePassiveMode];
    
    if (self.streamInfo.writeStream==nil) {
        InfoLog(@"Can't open the write stream! Possibly wrong URL!");
        self.error = [[WRRequestError alloc] init];
        self.error.errorCode = kWRFTPClientCantOpenStream;
        if(self.completion) self.completion(false);
        return;
    }
    
    self.streamInfo.writeStream.delegate = self;
    [self.streamInfo.writeStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    [self.streamInfo.writeStream open];
    
    self.didManagedToOpenStream = NO;
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, kWRDefaultTimeout * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        if (!self.didManagedToOpenStream && self.error==nil) {
            InfoLog(@"No response from the server. Timeout.");
            self.error = [[WRRequestError alloc] init];
            self.error.errorCode = kWRFTPClientStreamTimedOut;
            if(self.completion) self.completion(false);
            [self destroy];
        }
    });
}


//stream delegate
- (void)stream:(NSStream *)theStream handleEvent:(NSStreamEvent)streamEvent {
    
    switch (streamEvent) {
        case NSStreamEventOpenCompleted: {
            self.didManagedToOpenStream = YES;
        } break;
        case NSStreamEventHasBytesAvailable: {
        
        } break;
        case NSStreamEventHasSpaceAvailable: {
            
        } break;
        case NSStreamEventErrorOccurred: {
            self.error = [[WRRequestError alloc] init];
            self.error.errorCode = [self.error errorCodeWithError:[theStream streamError]];
            InfoLog(@"%@", self.error.message);
            if(self.completion) self.completion(false);
            [self destroy];
        } break;
        case NSStreamEventEndEncountered: {
            if(self.completion) self.completion(true);
            [self destroy];
        } break;
            
        case NSStreamEventNone:
        {
            ;
        }break;
    }
}

@end














/*======================================================WRRequestListDir============================================================*/

@interface WRRequestListDirectory ()

@property (nonatomic, strong) NSMutableData * listData;

@end

@implementation WRRequestListDirectory
@synthesize filesInfo;


-(NSString *)path {
    //  the path will always point to a directory, so we add the final slash to it (if there was one before escaping/standardizing, it's *gone* now)
    NSString * directoryPath = [super path];
    if (![directoryPath isEqualToString:@""]) {
        directoryPath = [directoryPath stringByAppendingString:@"/"];
    }
    return directoryPath;
}

-(void) start {
    assert(self.hostname != nil);
    
    self.listData = [NSMutableData data];

    // a little bit of C because I was not able to make NSInputStream play nice
    CFReadStreamRef readStreamRef = CFReadStreamCreateWithFTPURL(NULL, (__bridge CFURLRef)self.fullURL);
    self.streamInfo.readStream = (NSInputStream *)CFBridgingRelease(readStreamRef);
    
    [self.streamInfo.readStream setProperty:(id)(self.passive ? kCFBooleanTrue : kCFBooleanFalse) forKey:(id)kCFStreamPropertyFTPUsePassiveMode];
    
    if (self.streamInfo.readStream==nil) {
        InfoLog(@"Can't open the read stream! Possibly wrong URL!");
        self.error = [[WRRequestError alloc] init];
        self.error.errorCode = kWRFTPClientCantOpenStream;
        if(self.completion) self.completion(false);
        return;
    }
    
    self.streamInfo.readStream.delegate = self;
	[self.streamInfo.readStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
	[self.streamInfo.readStream open];
    
    self.didManagedToOpenStream = NO;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, kWRDefaultTimeout * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        if (!self.didManagedToOpenStream&&self.error==nil) {
            InfoLog(@"No response from the server. Timeout.");
            self.error = [[WRRequestError alloc] init];
            self.error.errorCode = kWRFTPClientStreamTimedOut;
            if(self.completion) self.completion(false);
            [self destroy];
        }
    });

}

//stream delegate
- (void)stream:(NSStream *)theStream handleEvent:(NSStreamEvent)streamEvent {
    
    switch (streamEvent) {
        case NSStreamEventOpenCompleted: {
			self.filesInfo = [NSMutableArray array];
            self.didManagedToOpenStream = YES;
        } break;
        case NSStreamEventHasBytesAvailable: {
            
            self.streamInfo.bytesConsumedThisIteration = [self.streamInfo.readStream read:self.streamInfo.buffer maxLength:kWRDefaultBufferSize];
            
            if (self.streamInfo.bytesConsumedThisIteration!=-1) {
                if (self.streamInfo.bytesConsumedThisIteration!=0) {
                    NSUInteger  offset = 0;
                    CFIndex     parsedBytes;
                    
                    [self.listData appendBytes:self.streamInfo.buffer length:self.streamInfo.bytesConsumedThisIteration];
                    
                    do {
                        
                        CFDictionaryRef listingEntity = NULL;
                        
                        parsedBytes = CFFTPCreateParsedResourceListing(NULL, &((const uint8_t *) self.listData.bytes)[offset], self.listData.length - offset, &listingEntity);
                        
                        if (parsedBytes > 0) {
                            if (listingEntity != NULL) {            
                                self.filesInfo = [self.filesInfo arrayByAddingObject:(NSDictionary *)CFBridgingRelease(listingEntity)];
                            }            
                            offset += (NSUInteger)parsedBytes;
                        }
                        
                    } while (parsedBytes > 0);

                    if(offset != 0) {
                        [self.listData replaceBytesInRange:NSMakeRange(0, offset) withBytes:NULL length:0];
                    }
                }
            }else{
                InfoLog(@"Stream opened, but failed while trying to read from it.");
                self.error = [[WRRequestError alloc] init];
                self.error.errorCode = kWRFTPClientCantReadStream;
                if(self.completion) self.completion(false);
                [self destroy];
            }
            
            
        } break;
        case NSStreamEventHasSpaceAvailable: {
            
        } break;
        case NSStreamEventErrorOccurred: {
            self.error = [[WRRequestError alloc] init];
            self.error.errorCode = [self.error errorCodeWithError:[theStream streamError]];
            InfoLog(@"%@", self.error.message);
            if(self.completion) self.completion(false);
            [self destroy];
        } break;
        case NSStreamEventEndEncountered: {            
            [WRBase addFoldersToCache:self.filesInfo forParentFolderPath:self.path];
            if(self.completion) self.completion(true);
            [self destroy];
        } break;
            
            
        case NSStreamEventNone:
        {
            
        } break;
    }
}



@end



/*======================================================WRRequestError============================================================*/

@implementation WRRequestError
@synthesize errorCode;

- (id)init {
    self = [super init];
    if (self) {
        self.errorCode = 0;
    }
    return self;
}

-(NSError *) nserror {
    
    return [NSError errorWithDomain:@"whiteracoon"
                               code:errorCode
                           userInfo:@{ NSLocalizedDescriptionKey: self.message }];
    
}

-(NSString *) message {
    
    switch (self.errorCode) {
        //Client errors
        case kWRFTPClientCantOpenStream:
            return @"Can't open stream, probably the URL is wrong.";
        case kWRFTPClientStreamTimedOut:
            return @"No response from the server. Timeout.";
        case kWRFTPClientCantReadStream:
            return @"The read stream had opened, but it failed while trying to read from it.";
        case kWRFTPClientCantWriteStream:
            return @"The write stream had opened, but it failed while trying to write to it.";
        case kWRFTPClientCantOverwriteDirectory:
            return @"Unable to overwrite directory!";
        case kWRFTPClientFileAlreadyExists:
            return@"File already exists!";
        //Server errors
        case kWRFTPServerAbortedTransfer:
            return @"Server connection interrupted.";
        case kWRFTPServerCantOpenDataConnection:
            return @"Server can't open data connection.";
        case kWRFTPServerFileNotAvailable:
            return @"Permission denied or no such file or directory";
        case kWRFTPServerIllegalFileName:
            return @"File name has illegal characters.";
        case kWRFTPServerResourceBusy:
            return @"Resource busy! Try again later!";
        case kWRFTPServerStorageAllocationExceeded:
            return @"Server storage exceeded!";
        case kWRFTPServerUserNotLoggedIn:
            return @"User not logged in";
        case kCFURLUnknownSchemeError:
            return @"Unknown scheme error";
        case kCFURLResourceNotFoundError:
            return @"Resource not found";
        case kCFURLResourceAccessViolationError:
            return @"Аccess to the resource is denied";
        case kCFURLRemoteHostUnavailableError:
            return @"Remote host unavailable";
        case kCFURLImproperArgumentsError:
            return @"Improper request arguments";
        case kCFURLUnknownPropertyKeyError:
            return @"Unknown property key";
        case kCFURLPropertyKeyUnavailableError:
            return @"Property key unavailable";
        case kCFURLTimeoutError:
            return @"No response from the server. Timeout.";
        default:
            return @"Unknown error!";
    }
}


-(WRErrorCodes) errorCodeWithError:(NSError *) error {

    WRErrorCodes code = [[error.userInfo objectForKey:(NSString*)kCFFTPStatusCodeKey] intValue];
    
    return code;
}


@end
