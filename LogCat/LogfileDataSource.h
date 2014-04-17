//
//  LogfileDataSource.h
//  LogCat
//
//  Created by Jan Rose on 15.04.14.
//  Copyright (c) 2014 SplashSoftware.pl. All rights reserved.
//

#import "LogDatasource.h"

@interface LogfileDataSource : LogDatasource

- (void)readLogFromURL:(NSURL*)url;

@end
