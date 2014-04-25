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
        regExpBrief = [NSRegularExpression regularExpressionWithPattern:@"^([VDIWEAF])" //level
                                                                        "\\/([^)]{0,23}?)" //tag
                                                                        "\\(\\s*(\\d+)\\)" //pid
                                                                        ":\\s+(.*)$" //message
                                                                options:NSRegularExpressionCaseInsensitive
                                                                  error:&error];
        
        regExpThreadtime = [NSRegularExpression regularExpressionWithPattern:   @"^(\\d{2}-\\d{2}\\s\\d{2}:\\d{2}:\\d{2}\\.\\d+)"//time
                                                                                "\\s*(\\d+)" //pid
                                                                                "\\s*(\\d+)" //tid
                                                                                "\\s([VDIWEAF])" //level
                                                                                "\\s(.*?)" //tag
                                                                                ":\\s+(.*)$" //message
                                                                     options:NSRegularExpressionCaseInsensitive
                                                                       error:&error];
        
        regExpTime = [NSRegularExpression regularExpressionWithPattern:@"^(\\d{2}-\\d{2}\\s\\d{2}:\\d{2}:\\d{2}\\.\\d+)" //time
                                                                        ":*\\s([VDIWEAF])" //level
                                                                        "\\/(.*?)" //tag
                                                                        "\\((\\d+)\\)" //pid
                                                                        ":\\s+(.*)$" //message
                                                               options:NSRegularExpressionCaseInsensitive
                                                                 error:&error];
        if(!regExpTime)
        {
            NSLog(@"error: %@", error);
        }
        
        regExpProcess = [NSRegularExpression regularExpressionWithPattern:  @"^([VDIWEAF])" //level
                                                                            "\\(\\s*(\\d+)\\)" //pid
                                                                            "\\s+(.*)$" //message
                                                                  options:NSRegularExpressionCaseInsensitive
                                                                    error:&error];
        
        regExpTag = [NSRegularExpression regularExpressionWithPattern:  @"^([VDIWEAF])" //level
                                                                        "\\/([^)]{0,23}?)" //tag
                                                                        ":\\s+(.*)$" //message
                                                              options:NSRegularExpressionCaseInsensitive
                                                                error:&error];
        
        regExpThread = [NSRegularExpression regularExpressionWithPattern:   @"^([VDIWEAF])" //level
                                                                            "\\(\\s*(\\d+)" //pid
                                                                            ":(0x.*?)" //tid
                                                                            "\\)\\s+(.*)$" //message
                                                                 options:NSRegularExpressionCaseInsensitive
                                                                   error:&error];
        
        regExpDdmsSave = [NSRegularExpression regularExpressionWithPattern:@"^(\\d{2}-\\d{2}\\s\\d{2}:\\d{2}:\\d{2}\\.\\d+)" //time
                                                                            ":*\\s(VERBOSE|DEBUG|ERROR|WARN|INFO|ASSERT)" //level
                                                                            "\\/(.*?)" //tag
                                                                            "\\((\\s*\\d+)\\)" //pid
                                                                            ":\\s+(.*)$" //message
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
        BOOL parseSuccess = [self tryReadWithTimePatternForLine:line];
        
        if (!parseSuccess) {
            parseSuccess = [self tryReadWithBriefPatternForLine:line];
        }
        
        if (!parseSuccess) {
            parseSuccess = [self tryReadWithThreadtimePatternForLine:line];
        }
        
        if (!parseSuccess) {
            parseSuccess = [self tryReadWithThreadPatternForLine:line];
        }
        
        if (!parseSuccess) {
            parseSuccess = [self tryReadWithTagPatternForLine:line];
        }
        
        if (!parseSuccess) {
            parseSuccess = [self tryReadWithProcessPatternForLine:line];
        }
        
        if (!parseSuccess) {
            parseSuccess = [self tryReadWithDdmsSavePatternForLine:line];
        }
        
        if (!parseSuccess) {
            NSLog(@"could not read line: %@", line);
        }
        
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

- (BOOL)tryReadWithTimePatternForLine:(NSString*)line
{
    NSUInteger numberOfMatches = [regExpTime numberOfMatchesInString:line options:0 range:NSMakeRange(0, line.length)];
    
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
        return YES;
    }
    
    return NO;
}

- (BOOL)tryReadWithBriefPatternForLine:(NSString*)line
{
    NSUInteger numberOfMatches = [regExpBrief numberOfMatchesInString:line options:0 range:NSMakeRange(0, line.length)];
    NSLog(@"number of matches: %lu", (unsigned long)numberOfMatches);
    
    if(numberOfMatches == 1)
    {
        NSArray *matches = [regExpBrief matchesInString:line
                                               options:0
                                                 range:NSMakeRange(0, [line length])];
        
        NSTextCheckingResult *match = [matches objectAtIndex:0];
        
        NSRange levelRange = [match rangeAtIndex:1];
        NSString* level = [line substringWithRange:levelRange];
        
        NSRange tagRange = [match rangeAtIndex:2];
        NSString* tag = [line substringWithRange:tagRange];
        
        NSRange pidRange = [match rangeAtIndex:3];
        NSString* pid = [line substringWithRange:pidRange];
        
        NSRange msgRange = [match rangeAtIndex:4];
        NSString* msg = [line substringWithRange:msgRange];
        
        //time, app, pid, tid, type, name, text,
        NSArray* values = @[[self getIndex], @"", @"", pid, @"", level, tag, msg];
        NSLog(@"entry: %@", values);
        NSDictionary* row = [NSDictionary dictionaryWithObjects:values forKeys:self.keysArray];
        [self appendRow:row];
        return YES;
    }
    
    return NO;
}

- (BOOL)tryReadWithThreadtimePatternForLine:(NSString*)line
{
    NSUInteger numberOfMatches = [regExpThreadtime numberOfMatchesInString:line options:0 range:NSMakeRange(0, line.length)];
    NSLog(@"number of matches: %lu", (unsigned long)numberOfMatches);
    
    if(numberOfMatches == 1)
    {
        NSArray *matches = [regExpThreadtime matchesInString:line
                                                options:0
                                                  range:NSMakeRange(0, [line length])];
        
        NSTextCheckingResult *match = [matches objectAtIndex:0];
        
        NSRange timestampRange = [match rangeAtIndex:1];
        NSString *timestamp = [line substringWithRange:timestampRange];
        
        NSRange pidRange = [match rangeAtIndex:2];
        NSString* pid = [line substringWithRange:pidRange];
        
        NSRange tidRange = [match rangeAtIndex:3];
        NSString* tid = [line substringWithRange:tidRange];
        
        NSRange levelRange = [match rangeAtIndex:4];
        NSString* level = [line substringWithRange:levelRange];
        
        NSRange tagRange = [match rangeAtIndex:5];
        NSString* tag = [line substringWithRange:tagRange];
        
        NSRange msgRange = [match rangeAtIndex:6];
        NSString* msg = [line substringWithRange:msgRange];
        
        //time, app, pid, tid, type, name, text,
        NSArray* values = @[[self getIndex], timestamp, @"", pid, tid, level, tag, msg];
        NSLog(@"entry: %@", values);
        NSDictionary* row = [NSDictionary dictionaryWithObjects:values forKeys:self.keysArray];
        [self appendRow:row];
        return YES;
    }
    
    return NO;
}

- (BOOL)tryReadWithProcessPatternForLine:(NSString*)line
{
    NSUInteger numberOfMatches = [regExpProcess numberOfMatchesInString:line options:0 range:NSMakeRange(0, line.length)];
    NSLog(@"number of matches: %lu", (unsigned long)numberOfMatches);
    
    if(numberOfMatches == 1)
    {
        NSArray *matches = [regExpProcess matchesInString:line
                                                     options:0
                                                       range:NSMakeRange(0, [line length])];
        
        NSTextCheckingResult *match = [matches objectAtIndex:0];
        
        NSRange levelRange = [match rangeAtIndex:1];
        NSString* level = [line substringWithRange:levelRange];
        
        NSRange pidRange = [match rangeAtIndex:2];
        NSString* pid = [line substringWithRange:pidRange];
        
        NSRange msgRange = [match rangeAtIndex:3];
        NSString* msg = [line substringWithRange:msgRange];
        
        //time, app, pid, tid, type, name, text,
        NSArray* values = @[[self getIndex], @"", @"", pid, @"", level, @"", msg];
        NSLog(@"entry: %@", values);
        NSDictionary* row = [NSDictionary dictionaryWithObjects:values forKeys:self.keysArray];
        [self appendRow:row];
        return YES;
    }
    
    return NO;
}

- (BOOL)tryReadWithTagPatternForLine:(NSString*)line
{
    NSUInteger numberOfMatches = [regExpTag numberOfMatchesInString:line options:0 range:NSMakeRange(0, line.length)];
    NSLog(@"number of matches: %lu", (unsigned long)numberOfMatches);
    
    if(numberOfMatches == 1)
    {
        NSArray *matches = [regExpTag matchesInString:line
                                                  options:0
                                                    range:NSMakeRange(0, [line length])];
        
        NSTextCheckingResult *match = [matches objectAtIndex:0];
        
        NSRange levelRange = [match rangeAtIndex:1];
        NSString* level = [line substringWithRange:levelRange];
        
        NSRange tagRange = [match rangeAtIndex:2];
        NSString* tag = [line substringWithRange:tagRange];
        
        NSRange msgRange = [match rangeAtIndex:3];
        NSString* msg = [line substringWithRange:msgRange];
        
        //time, app, pid, tid, type, name, text,
        NSArray* values = @[[self getIndex], @"", @"", @"", @"", level, tag, msg];
        NSLog(@"entry: %@", values);
        NSDictionary* row = [NSDictionary dictionaryWithObjects:values forKeys:self.keysArray];
        [self appendRow:row];
        return YES;
    }
    
    return NO;
}

- (BOOL)tryReadWithThreadPatternForLine:(NSString*)line
{
    NSUInteger numberOfMatches = [regExpThread numberOfMatchesInString:line options:0 range:NSMakeRange(0, line.length)];
    NSLog(@"number of matches: %lu", (unsigned long)numberOfMatches);
    
    if(numberOfMatches == 1)
    {
        NSArray *matches = [regExpThread matchesInString:line
                                                     options:0
                                                       range:NSMakeRange(0, [line length])];
        
        NSTextCheckingResult *match = [matches objectAtIndex:0];

        NSRange levelRange = [match rangeAtIndex:1];
        NSString* level = [line substringWithRange:levelRange];
        
        NSRange pidRange = [match rangeAtIndex:2];
        NSString* pid = [line substringWithRange:pidRange];
        
        NSRange tidRange = [match rangeAtIndex:3];
        NSString* tid = [line substringWithRange:tidRange];
        
        NSRange msgRange = [match rangeAtIndex:4];
        NSString* msg = [line substringWithRange:msgRange];
        
        //time, app, pid, tid, type, name, text,
        NSArray* values = @[[self getIndex], @"", @"", pid, tid, level, @"", msg];
        NSLog(@"entry: %@", values);
        NSDictionary* row = [NSDictionary dictionaryWithObjects:values forKeys:self.keysArray];
        [self appendRow:row];
        return YES;
    }
    
    return NO;
}

- (BOOL)tryReadWithDdmsSavePatternForLine:(NSString*)line
{
    NSUInteger numberOfMatches = [regExpDdmsSave numberOfMatchesInString:line options:0 range:NSMakeRange(0, line.length)];
    NSLog(@"number of matches: %lu", (unsigned long)numberOfMatches);
    
    if(numberOfMatches == 1)
    {
        NSArray *matches = [regExpDdmsSave matchesInString:line
                                                 options:0
                                                   range:NSMakeRange(0, [line length])];
        
        NSTextCheckingResult *match = [matches objectAtIndex:0];
        
        NSRange timestampRange = [match rangeAtIndex:1];
        NSString *timestamp = [line substringWithRange:timestampRange];
        
        NSRange levelRange = [match rangeAtIndex:4];
        NSString* level = [line substringWithRange:levelRange];
        
        NSRange tagRange = [match rangeAtIndex:5];
        NSString* tag = [line substringWithRange:tagRange];
        
        NSRange pidRange = [match rangeAtIndex:2];
        NSString* pid = [line substringWithRange:pidRange];
        
        NSRange msgRange = [match rangeAtIndex:6];
        NSString* msg = [line substringWithRange:msgRange];
        
        //time, app, pid, tid, type, name, text,
        NSArray* values = @[[self getIndex], timestamp, @"", pid, @"", level, tag, msg];
        NSLog(@"entry: %@", values);
        NSDictionary* row = [NSDictionary dictionaryWithObjects:values forKeys:self.keysArray];
        [self appendRow:row];
        return YES;
    }
    
    return NO;
}
@end
