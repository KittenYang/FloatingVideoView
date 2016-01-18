//
//  HCYoutube.m
//  YoutubeParser
//
//  Created by Simon Andersson on 6/4/12.
//  Copyright (c) 2012 Hiddencode.me. All rights reserved.
//

#import "HCYoutubeParser.h"

#define kYoutubeInfoURL      @"https://www.youtube.com/get_video_info?video_id="
#define kYoutubeThumbnailURL @"https://img.youtube.com/vi/%@/%@.jpg"
#define kYoutubeDataURL      @"https://gdata.youtube.com/feeds/api/videos/%@?alt=json"
#define kUserAgent @"Mozilla/5.0 (Macintosh; Intel Mac OS X 10_8_2) AppleWebKit/537.4 (KHTML, like Gecko) Chrome/22.0.1229.79 Safari/537.4"

@interface NSString (QueryString)

/**
 Parses a query string
 
 @return key value dictionary with each parameter as an array
 */
- (NSMutableDictionary *)dictionaryFromQueryStringComponents;


/**
 Convenient method for decoding a html encoded string
 */
- (NSString *)stringByDecodingURLFormat;

@end

@interface NSURL (QueryString)

/**
 Parses a query string of an NSURL
 
 @return key value dictionary with each parameter as an array
 */
- (NSMutableDictionary *)dictionaryForQueryString;

@end

@implementation NSString (QueryString)

- (NSString *)stringByDecodingURLFormat {
    NSString *result = [self stringByReplacingOccurrencesOfString:@"+" withString:@" "];
    result = [result stringByRemovingPercentEncoding];
    return result;
}

//把下载的一堆文字转换成一个可变字典
- (NSMutableDictionary *)dictionaryFromQueryStringComponents {

    NSMutableDictionary *parameters = [NSMutableDictionary dictionary];

    //用 "&" 来分割这堆字符串，形如 ptchn=9PgszLOAWhQC6orYejcJlw，用变量 keyValue 表示
    for (NSString *keyValue in [self componentsSeparatedByString:@"&"]) {
        //用 "=" 重新分割每一个 keyValue.
        NSArray *keyValueArray = [keyValue componentsSeparatedByString:@"="];
        if ([keyValueArray count] < 2) {
            continue;
        }
        //取出等号的左边，例如上面的 ptchn，用变量 key 表示。把 "+" 转换成空格。
        NSString *key = [[keyValueArray objectAtIndex:0] stringByDecodingURLFormat];
        //取出等号的右边，例如上面的 9PgszLOAWhQC6orYejcJlw，用变量 value 表示。把 "+" 转换成空格。
        NSString *value = [[keyValueArray objectAtIndex:1] stringByDecodingURLFormat];

        NSMutableArray *results = [parameters objectForKey:key];

        if(!results) {
            results = [NSMutableArray arrayWithCapacity:1];
            [parameters setObject:results forKey:key];
        }
        // 把 key 和 value 存放到一个字典里面
        [results addObject:value];
    }

    // 通过for-in loop, 最后返回一个大字典，{ ptchn:9PgszLOAWhQC6orYejcJlw，enablecsi:1,iurlsd:https%3A%2F%2Fi.ytimg.com%2Fvi%2FtMWaRkMvkzg%2Fsddefault.jpg ......}
    return parameters;
}

@end

@implementation NSURL (QueryString)

- (NSMutableDictionary *)dictionaryForQueryString {
    return [[self query] dictionaryFromQueryStringComponents];
}

@end

@implementation HCYoutubeParser

+ (NSString *)youtubeIDFromYoutubeURL:(NSURL *)youtubeURL {
    NSString *youtubeID = nil;
    
    if ([youtubeURL.host isEqualToString:@"youtu.be"]) {
        youtubeID = [[youtubeURL pathComponents] objectAtIndex:1];
    } else if([youtubeURL.absoluteString rangeOfString:@"www.youtube.com/embed"].location != NSNotFound){
        youtubeID = [[youtubeURL pathComponents] objectAtIndex:2];
    } else if([youtubeURL.host isEqualToString:@"youtube.googleapis.com"] ||
              [[youtubeURL.pathComponents firstObject] isEqualToString:@"www.youtube.com"]) {
        youtubeID = [[youtubeURL pathComponents] objectAtIndex:2];
    } else {
        youtubeID = [[[youtubeURL dictionaryForQueryString] objectForKey:@"v"] objectAtIndex:0];
    }
    return youtubeID;
}

+ (NSDictionary *)h264videosWithYoutubeID:(NSString *)youtubeID {
    if (youtubeID) {
        NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"%@%@", kYoutubeInfoURL, youtubeID]];
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
        [request setValue:kUserAgent forHTTPHeaderField:@"User-Agent"];
        [request setHTTPMethod:@"GET"];
        
        __block NSDictionary *data = nil;
        
        // Lock threads with semaphore
        dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
        [[[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData * _Nullable responseData, NSURLResponse * _Nullable response, NSError * _Nullable error) {
            
            if (!error) {
                NSString *responseString = [[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding];
                
                NSMutableDictionary *parts = [responseString dictionaryFromQueryStringComponents];
                
                if (parts) {
                    //取出 key 为 url_encoded_fmt_stream_map 的 value.
                    NSString *fmtStreamMapString = [[parts objectForKey:@"url_encoded_fmt_stream_map"] objectAtIndex:0];
                    if (fmtStreamMapString.length > 0) {
                        //用 "," 分割出不同分辨率的视频，quality=hd720、quality=medium、.....
                        NSArray *fmtStreamMapArray = [fmtStreamMapString componentsSeparatedByString:@","];
                        
                        NSMutableDictionary *videoDictionary = [NSMutableDictionary dictionary];
                        //遍历每个分辨率的视频，同样调用之前的方法，把字符串分割中 key 和 value 的字典。
                        for (NSString *videoEncodedString in fmtStreamMapArray) {
                            NSMutableDictionary *videoComponents = [videoEncodedString dictionaryFromQueryStringComponents];
                            NSString *type = [[[videoComponents objectForKey:@"type"] objectAtIndex:0] stringByDecodingURLFormat];
                            NSString *signature = nil;
                            
                            if (![videoComponents objectForKey:@"stereo3d"]) {
                                if ([videoComponents objectForKey:@"itag"]) {
                                    signature = [[videoComponents objectForKey:@"itag"] objectAtIndex:0];
                                }
                                
                                if (signature && [type rangeOfString:@"mp4"].length > 0) {
                                    NSString *url = [[[videoComponents objectForKey:@"url"] objectAtIndex:0] stringByDecodingURLFormat];
                                    url = [NSString stringWithFormat:@"%@&signature=%@", url, signature];
                                    
                                    NSString *quality = [[[videoComponents objectForKey:@"quality"] objectAtIndex:0] stringByDecodingURLFormat];
                                    if ([videoComponents objectForKey:@"stereo3d"] && [[videoComponents objectForKey:@"stereo3d"] boolValue]) {
                                        quality = [quality stringByAppendingString:@"-stereo3d"];
                                    }
                                    if([videoDictionary valueForKey:quality] == nil) {
                                        [videoDictionary setObject:url forKey:quality];
                                    }
                                }
                            }
                        }
                        
                        // add some extra information about this video to the dictionary we pass back to save on the amounts of network requests
                        if (videoDictionary.count > 0)
                        {
                            NSMutableDictionary *optionsDict = [NSMutableDictionary dictionary];
                            NSArray *keys = @[//@"author", // youtube channel name
                                              //@"avg_rating", // average ratings on yt when downloaded
                                              @"iurl", //@"iurlmaxres", @"iurlsd", // thumbnail urls
                                              //@"keywords", // author defined keywords
                                              @"length_seconds", // total duration in seconds
                                              @"title", // video title
                                              //@"video_id"
                                              ]; // youtube id
                            
                            for (NSString *key in keys)
                            {
                                [optionsDict setObject:parts[key][0] forKey:key]; // [0] because we want the object and not the array
                            }
                            
                            [videoDictionary setObject:optionsDict forKey:@"moreInfo"];
                        }
                        
                        data = videoDictionary;
                        dispatch_semaphore_signal(semaphore);
                    }
                    // Check for live data
                    else if ([parts objectForKey:@"live_playback"] != nil && [parts objectForKey:@"hlsvp"] != nil && [[parts objectForKey:@"hlsvp"] count] > 0) {
                        data = @{ @"live": [parts objectForKey:@"hlsvp"][0] };
                        dispatch_semaphore_signal(semaphore);
                        
                    } else {
                        
                        //No data at all, just unlock the sema
                        dispatch_semaphore_signal(semaphore);
                    }
                }
            }
        }] resume];
        dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
        
        return data;
    }
    return nil;
}

+ (NSDictionary *)h264videosWithYoutubeURL:(NSURL *)youtubeURL {
    
    NSString *youtubeID = [self youtubeIDFromYoutubeURL:youtubeURL];
    return [self h264videosWithYoutubeID:youtubeID];
}

+ (void)h264videosWithYoutubeURL:(NSURL *)youtubeURL
                   completeBlock:(void(^)(NSDictionary *videoDictionary, NSError *error))completeBlock {
    NSString *youtubeID = [self youtubeIDFromYoutubeURL:youtubeURL];
    if (youtubeID) {
        dispatch_queue_t queue = dispatch_queue_create("me.hiddencode.yt.backgroundqueue", 0);
        dispatch_async(queue, ^{
            NSDictionary *dict = [[self class] h264videosWithYoutubeID:youtubeID];
            dispatch_async(dispatch_get_main_queue(), ^{
                completeBlock(dict, nil);
            });
        });
    }
    else {
        completeBlock(nil, [NSError errorWithDomain:@"me.hiddencode.yt-parser" code:1001 userInfo:@{ NSLocalizedDescriptionKey: @"Invalid YouTube URL" }]);
    }
}

+ (void)thumbnailForYoutubeURL:(NSURL *)youtubeURL
                 thumbnailSize:(YouTubeThumbnail)thumbnailSize
                 completeBlock:(void(^)(HCImage *image, NSError *error))completeBlock {
    NSString *youtubeID = [self youtubeIDFromYoutubeURL:youtubeURL];
    return [self thumbnailForYoutubeID:youtubeID thumbnailSize:thumbnailSize completeBlock:completeBlock];
}

+ (NSURL *)thumbnailUrlForYoutubeURL:(NSURL *)youtubeURL
                       thumbnailSize:(YouTubeThumbnail)thumbnailSize{
    NSURL *url = nil;

    if(youtubeURL){
        NSString *thumbnailSizeString = nil;
        switch (thumbnailSize) {
            case YouTubeThumbnailDefault:
                thumbnailSizeString = @"default";
                break;
            case YouTubeThumbnailDefaultMedium:
                thumbnailSizeString = @"mqdefault";
                break;
            case YouTubeThumbnailDefaultHighQuality:
                thumbnailSizeString = @"hqdefault";
                break;
            case YouTubeThumbnailDefaultMaxQuality:
                thumbnailSizeString = @"maxresdefault";
                break;
            default:
                thumbnailSizeString = @"default";
                break;
        }
        NSString *youtubeID = [self youtubeIDFromYoutubeURL:youtubeURL];
        url = [NSURL URLWithString:[NSString stringWithFormat:kYoutubeThumbnailURL, youtubeID, thumbnailSizeString]];
    }

    return  url;
}

+ (void)thumbnailForYoutubeID:(NSString *)youtubeID thumbnailSize:(YouTubeThumbnail)thumbnailSize completeBlock:(void (^)(HCImage *, NSError *))completeBlock {
    if (youtubeID) {
        NSString *thumbnailSizeString = nil;
        switch (thumbnailSize) {
            case YouTubeThumbnailDefault:
                thumbnailSizeString = @"default";
                break;
            case YouTubeThumbnailDefaultMedium:
                thumbnailSizeString = @"mqdefault";
                break;
            case YouTubeThumbnailDefaultHighQuality:
                thumbnailSizeString = @"hqdefault";
                break;
            case YouTubeThumbnailDefaultMaxQuality:
                thumbnailSizeString = @"maxresdefault";
                break;
            default:
                thumbnailSizeString = @"default";
                break;
        }

        NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:kYoutubeThumbnailURL, youtubeID, thumbnailSizeString]];
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
        [request setValue:kUserAgent forHTTPHeaderField:@"User-Agent"];
        [request setHTTPMethod:@"GET"];

        [[[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
            
            if (!error) {
                HCImage *image = [[HCImage alloc] initWithData:data];
                completeBlock(image, nil);
            }
            else {
                completeBlock(nil, error);
            }
        }] resume];
    }
    else {
        NSDictionary *details = @{ NSLocalizedDescriptionKey : @"Could not find a valid Youtube ID" };
        NSError *error = [NSError errorWithDomain:@"com.hiddencode.yt-parser" code:0 userInfo:details];
        completeBlock(nil, error);
    }
}

+ (void)detailsForYouTubeURL:(NSURL *)youtubeURL
               completeBlock:(void(^)(NSDictionary *details, NSError *error))completeBlock {
    NSString *youtubeID = [self youtubeIDFromYoutubeURL:youtubeURL];
    if (youtubeID)
    {
        NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:[NSString stringWithFormat:kYoutubeDataURL, youtubeID]]];

        [[[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
            if (!error) {
                NSDictionary* json = [NSJSONSerialization JSONObjectWithData:data
                                                                     options:kNilOptions
                                                                       error:&error];
                if (!error) {
                    completeBlock(json, nil);
                }
                else {
                    completeBlock(nil, error);
                }
            }
            else {
                completeBlock(nil, error);
            }
        }] resume];
    }
    else
    {
        NSDictionary *details = @{ NSLocalizedDescriptionKey : @"Could not find a valid Youtube ID" };
        NSError *error = [NSError errorWithDomain:@"com.hiddencode.yt-parser" code:0 userInfo:details];
        completeBlock(nil, error);
    }
}

@end
