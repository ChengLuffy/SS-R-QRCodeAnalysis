//
//  QRCodeUtils.m
//  ShadowsocksX-NG
//
//  Created by 邱宇舟 on 16/6/8.
//  Copyright © 2016年 qiuyuzhou. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreImage/CoreImage.h>

void ScanQRCodeOnScreen() {
    /* displays[] Quartz display ID's */
    CGDirectDisplayID   *displays = nil;
    
    CGError             err = CGDisplayNoErr;
    CGDisplayCount      dspCount = 0;
    
    /* How many active displays do we have? */
    err = CGGetActiveDisplayList(0, NULL, &dspCount);
    
    /* If we are getting an error here then their won't be much to display. */
    if(err != CGDisplayNoErr)
    {
        NSLog(@"Could not get active display count (%d)\n", err);
        return;
    }
    
    /* Allocate enough memory to hold all the display IDs we have. */
    displays = calloc((size_t)dspCount, sizeof(CGDirectDisplayID));
    
    // Get the list of active displays
    err = CGGetActiveDisplayList(dspCount,
                                 displays,
                                 &dspCount);
    
    /* More error-checking here. */
    if(err != CGDisplayNoErr)
    {
        NSLog(@"Could not get active display list (%d)\n", err);
        return;
    }
    
    NSMutableArray* foundSSUrls = [NSMutableArray array];
    
    CIDetector *detector = [CIDetector detectorOfType:@"CIDetectorTypeQRCode"
                                              context:nil
                                              options:@{ CIDetectorAccuracy:CIDetectorAccuracyHigh }];
    
    for (unsigned int displaysIndex = 0; displaysIndex < dspCount; displaysIndex++)
    {
        /* Make a snapshot image of the current display. */
        CGImageRef image = CGDisplayCreateImage(displays[displaysIndex]);
        NSArray *features = [detector featuresInImage:[CIImage imageWithCGImage:image]];
        for (CIQRCodeFeature *feature in features) {
            NSLog(@"%@", feature.messageString);
            if ( [feature.messageString hasPrefix:@"ss://"] )
            {
                [foundSSUrls addObject:[NSURL URLWithString:feature.messageString]];
            }else if ( [feature.messageString hasPrefix:@"ssr://"] ){
                [foundSSUrls addObject:[NSURL URLWithString:feature.messageString]];
            } else {
                [foundSSUrls addObject:[NSURL URLWithString:feature.messageString]];
            }
        }
    }
    
    free(displays);
    
    [[NSNotificationCenter defaultCenter]
     postNotificationName:@"NOTIFY_FOUND_SS_URL"
     object:nil
     userInfo: @{ @"urls": foundSSUrls,
                  @"source": @"qrcode"
                 }
     ];
}

// 解析SS URL，如果成功则返回一个与ServerProfile类兼容的dict
// 或SSR URL，ServerProfile类已经默认添加SSR参数，默认放空，如果URL为SSR://则改变解析方法
// ss:// + base64(method:password@domain:port)
NSDictionary<NSString *, id>* ParseSSURL(NSURL* url) {
    if (!url.host) {
        return nil;
    }
    
    NSString *urlString = [url absoluteString];
    int i = 0;
    NSString *errorReason = nil;
    if([urlString hasPrefix:@"ss://"]){
        while(i < 2) {
            if (i == 1) {
                NSString* host = url.host;
                if ([host length]%4!=0) {
                    int n = 4 - [host length]%4;
                    if (1==n) {
                        host = [host stringByAppendingString:@"="];
                    } else if (2==n) {
                        host = [host stringByAppendingString:@"=="];
                    }
                }
                NSData *data = [[NSData alloc] initWithBase64EncodedString:host options:0];
                NSString *decodedString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                urlString = decodedString;
            }
            i++;
            urlString = [urlString stringByReplacingOccurrencesOfString:@"ss://" withString:@"" options:NSAnchoredSearch range:NSMakeRange(0, urlString.length)];
            NSRange firstColonRange = [urlString rangeOfString:@":"];
            NSRange lastColonRange = [urlString rangeOfString:@":" options:NSBackwardsSearch];
            NSRange lastAtRange = [urlString rangeOfString:@"@" options:NSBackwardsSearch];
            if (firstColonRange.length == 0) {
                errorReason = @"colon not found";
                continue;
            }
            if (firstColonRange.location == lastColonRange.location) {
                errorReason = @"only one colon";
                continue;
            }
            if (lastAtRange.length == 0) {
                errorReason = @"at not found";
                continue;
            }
            if (!((firstColonRange.location < lastAtRange.location) && (lastAtRange.location < lastColonRange.location))) {
                errorReason = @"wrong position";
                continue;
            }
            NSString *method = [urlString substringWithRange:NSMakeRange(0, firstColonRange.location)];
            NSString *password = [urlString substringWithRange:NSMakeRange(firstColonRange.location + 1, lastAtRange.location - firstColonRange.location - 1)];
            NSString *IP = [urlString substringWithRange:NSMakeRange(lastAtRange.location + 1, lastColonRange.location - lastAtRange.location - 1)];
            NSString *port = [urlString substringWithRange:NSMakeRange(lastColonRange.location + 1, urlString.length - lastColonRange.location - 1)];
            
            
            return @{@"ServerHost": IP,
                     @"ServerPort": @([port integerValue]),
                     @"Method": method,
                     @"Password": password,
                     };
        }

    }else if ([urlString hasPrefix:@"ssr://"]){
        // ssr:// + base64(abc.xyz:12345:auth_sha1_v2:rc4-md5:tls1.2_ticket_auth:{base64(password)}/?obfsparam={base64(混淆参数(网址))}&remarks={base64(节点名称)})
        urlString = [urlString stringByReplacingOccurrencesOfString:@"ssr://" withString:@"" options:NSAnchoredSearch range:NSMakeRange(0, urlString.length)];
        NSData *data = [[NSData alloc] initWithBase64EncodedString:urlString options:0];
        NSString *decodedString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        urlString = decodedString;
        
        if (data == NULL) {
            [[NSNotificationCenter defaultCenter]
             postNotificationName:@"NOTIFY_INVALIDE_QR"
             object:nil
             userInfo: @{ @"urls": @"配置二维码无效!",
                          @"source": @"qrcode"
                          }
             ];
        }else{
            NSRange paramSplit = [decodedString rangeOfString:@"?"];
            NSString *firstParam = [decodedString substringToIndex:paramSplit.location-1];
            NSString *lastParam = [decodedString substringFromIndex:paramSplit.location];
            lastParam = [lastParam substringFromIndex:1];
            
            NSArray *lastParamArray = [lastParam componentsSeparatedByString:@"&"];
            NSMutableDictionary *parserLastParamDict = [[NSMutableDictionary alloc]init];
            for (int i=0; i<lastParamArray.count; i++) {
                NSString *toSplitString = lastParamArray[i];
                NSRange lastParamSplit = [toSplitString rangeOfString:@"="];
                if (lastParamSplit.location != NSNotFound) {
                    NSString *key = [toSplitString substringToIndex:lastParamSplit.location];
                    NSString *value =  [[NSString alloc] initWithData:[[NSData alloc] initWithBase64EncodedString:[toSplitString substringFromIndex:lastParamSplit.location+1] options:0]encoding:NSUTF8StringEncoding];
                    //                            NSString *value =  [toSplitString substringFromIndex:lastParamSplit.location+1];
                    [parserLastParamDict setValue: value forKey: key];
                }
            }
            NSLog(@"parserLastParamDict is %@",parserLastParamDict);
            
            //后面已经parser完成，接下来需要解析到profile里面
            //abc.xyz:12345:auth_sha1_v2:rc4-md5:tls1.2_ticket_auth:{base64(password)}
            NSRange range = [firstParam rangeOfString:@":"];
            NSString *ip = [firstParam substringToIndex:range.location];//第一个参数是域名
            
            firstParam = [firstParam substringFromIndex:range.location + range.length];
            range = [firstParam rangeOfString:@":"];
            NSString *port = [firstParam substringToIndex:range.location];//第二个参数是端口
            
            firstParam = [firstParam substringFromIndex:range.location + range.length];
            range = [firstParam rangeOfString:@":"];
            NSString *ssrProtocol = [firstParam substringToIndex:range.location];//第三个参数是协议
            
            firstParam = [firstParam substringFromIndex:range.location + range.length];
            range = [firstParam rangeOfString:@":"];
            NSString *encryption = [firstParam substringToIndex:range.location];//第四个参数是加密
            
            firstParam = [firstParam substringFromIndex:range.location + range.length];
            range = [firstParam rangeOfString:@":"];
            NSString *ssrObfs = [firstParam substringToIndex:range.location];//第五个参数是混淆协议
            
            firstParam = [firstParam substringFromIndex:range.location + range.length];
            //                    range = [firstParam rangeOfString:@":"];
            NSString *password = [[NSString alloc] initWithData:[[NSData alloc] initWithBase64EncodedString:firstParam options:0]encoding:NSUTF8StringEncoding];//第五个参数是base64密码
            
            NSString *ssrObfsParam = @"";
            NSString *remarks = @"";
            NSString *ssrProtocolParam = @"";
            for (NSString *key in parserLastParamDict) {
                NSLog(@"key: %@ value: %@", key, parserLastParamDict[key]);
                if ([key  isEqual: @"obfsparam"]) {
                    ssrObfsParam = parserLastParamDict[key];
                } else if ([key  isEqual: @"remarks"]) {
                    remarks = parserLastParamDict[key];
                } else if([key isEqual:@"protocolparam"]){
                    ssrProtocolParam = parserLastParamDict[key];
                }
            }
        
        return @{@"ServerHost":ip,
                 @"ServerPort": @([port integerValue]),
                 @"Method": encryption,
                 @"Password": password,
                 @"ssrObfs":ssrObfs,
                 @"ssrObfsParam":ssrObfsParam,
                 @"ssrProtocol":ssrProtocol,
                 @"ssrProtocolParam":ssrProtocolParam,
                 };
        }
    }
    return @{@"msg": urlString};
}
