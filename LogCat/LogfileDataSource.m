//
//  LogfileDataSource.m
//  LogCat
//
//  Created by Jan Rose on 15.04.14.
//  Copyright (c) 2014 SplashSoftware.pl. All rights reserved.
//

#import "LogfileDataSource.h"
#import "DDFileReader.h"

@interface LogfileDataSource()
{
    NSRegularExpression* regExpBrief;
    NSRegularExpression* regExpThreadtime;
    NSRegularExpression* regExpTime;
    NSRegularExpression* regExpProcess;
    NSRegularExpression* regExpTag;
    NSRegularExpression* regExpThread;
    NSRegularExpression* regExpDdmsSave;
}

@end

@implementation LogfileDataSource

- (id)init
{
    self = [super init];
    
    if(self)
    {
        NSError* error;
        regExpBrief = [NSRegularExpression regularExpressionWithPattern:@"^(?<level>[VDIWEAF])\\/(?<tag>[^)]{0,23}?)\\(\\s*(?<pid>\\d+)\\):\\s+(?<message>.*)$"
                                                                options:NSRegularExpressionCaseInsensitive
                                                                  error:&error];
        
        regExpThreadtime = [NSRegularExpression regularExpressionWithPattern:@"^(?<timestamp>\\d\\d-\\d\\d\\s\\d\\d:\\d\\d:\\d\\d\\.\\d+)\\s*(?<pid>\\d+)\\s*(?<tid>\\d+)\\s(?<level>[VDIWEAF])\\s(?<tag>.*?):\\s+(?<message>.*)$"
                                                                     options:NSRegularExpressionCaseInsensitive
                                                                       error:&error];
        
        regExpTime = [NSRegularExpression regularExpressionWithPattern:@"^(\\d{2}-\\d{2}\\s\\d{2}:\\d{2}:\\d{2}\\.\\d+):*\\s([VDIWEAF])\\/(.*?)\\((\\d+)\\):\\s+(.*)$"
                                                               options:NSRegularExpressionCaseInsensitive
                                                                 error:&error];
        if(!regExpTime)
        {
            NSLog(@"error: %@", error);
        }
        
        regExpProcess = [NSRegularExpression regularExpressionWithPattern:@"^(?<level>[VDIWEAF])\\(\\s*(?<pid>\\d+)\\)\\s+(?<message>.*)$"
                                                                  options:NSRegularExpressionCaseInsensitive
                                                                    error:&error];
        
        regExpTag = [NSRegularExpression regularExpressionWithPattern:@"^(?<level>[VDIWEAF])\\/(?<tag>[^)]{0,23}?):\\s+(?<message>.*)$"
                                                              options:NSRegularExpressionCaseInsensitive
                                                                error:&error];
        
        regExpThread = [NSRegularExpression regularExpressionWithPattern:@"^(?<level>[VDIWEAF])\\(\\s*(?<pid>\\d+):(?<tid>0x.*?)\\)\\s+(?<message>.*)$"
                                                                 options:NSRegularExpressionCaseInsensitive
                                                                   error:&error];
        
        regExpDdmsSave = [NSRegularExpression regularExpressionWithPattern:@"^(?<timestamp>\\d\\d-\\d\\d\\s\\d\\d:\\d\\d:\\d\\d\\.\\d+):*\\s(?<level>VERBOSE|DEBUG|ERROR|WARN|INFO|ASSERT)\\/(?<tag>.*?)\\((?<pid>\\s*\\d+)\\):\\s+(?<message>.*)$"
                                                                   options:NSRegularExpressionCaseInsensitive
                                                                     error:&error];
    }
    
    return self;
}

- (void)readLogFromURL:(NSURL *)url
{
    NSLog(@"reading log from URL: %@", url);
    isLogging = YES;
    [self performSelectorOnMainThread:@selector(onLoggerStarted) withObject:nil waitUntilDone:NO];
    
    DDFileReader* fileReader = [[DDFileReader alloc] initWithFilePath:url.path];
    
    [fileReader enumerateLinesUsingBlock:^(NSString* line, BOOL* stop) {
        NSLog(@"line: %@", line);
        //parse line
        NSUInteger numberOfMatches = [regExpTime numberOfMatchesInString:line options:0 range:NSMakeRange(0, line.length)];
        NSLog(@"number of matches: %lu", (unsigned long)numberOfMatches);
        
        if(numberOfMatches == 1)
        {
            NSArray *matches = [regExpTime matchesInString:line
                                                   options:0
                                                     range:NSMakeRange(0, [line length])];
            
            NSTextCheckingResult *match = [matches objectAtIndex:0];
            
            NSRange timestampRange = [match rangeAtIndex:1];
            NSString *timestamp = [line substringWithRange:timestampRange];
            
            NSRange levelRange = [match rangeAtIndex:2];
            NSString* level = [line substringWithRange:levelRange];
            
            NSRange tagRange = [match rangeAtIndex:3];
            NSString* tag = [line substringWithRange:tagRange];
            
            NSRange pidRange = [match rangeAtIndex:4];
            NSString* pid = [line substringWithRange:pidRange];
            
            NSRange msgRange = [match rangeAtIndex:5];
            NSString* msg = [line substringWithRange:msgRange];
            
            //time, app, pid, tid, type, name, text,
            NSArray* values = @[[self getIndex], timestamp, @"", pid, @"", level, tag, msg];
            NSLog(@"entry: %@", values);
            NSDictionary* row = [NSDictionary dictionaryWithObjects:values forKeys:self.keysArray];
            [self appendRow:row];
        }
        
        //TODO:
        
        
        
        
        
        
    }];
    
    [self performSelectorOnMainThread:@selector(onLogUpdated) withObject:nil waitUntilDone:YES];
    
//    NSLog(@"Exited readlog loop.");
//    isLogging = NO;
//
//    [self.pidMap removeAllObjects];
//    
//    [self performSelectorOnMainThread:@selector(onLoggerStopped) withObject:nil waitUntilDone:NO];
//    
//    [self stopLogger];
//    NSLog(@"ADB Exited.");
//    self.skipPidLookup = NO;
}

@end
