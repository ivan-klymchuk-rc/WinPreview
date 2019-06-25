
#import "AppDelegate.h"
#import "PreviewCollectionItem.h"
#import <Accelerate/Accelerate.h>

@interface AppDelegate ()

@property (weak) IBOutlet NSWindow *window;
@property (strong) NSArray *contents;
@property (assign) IBOutlet NSCollectionView *collectionView;
@property (strong) PreviewCollectionItem *collectionViewItem;
@property (strong) NSTimer *timer;

@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    self.timer = [NSTimer scheduledTimerWithTimeInterval:2.0
                                     target:self
                                   selector:@selector(refreshPreviews:)
                                   userInfo:nil
                                    repeats:YES];
    
    self.collectionViewItem = [PreviewCollectionItem new];
    
    [self.collectionView setItemPrototype:self.collectionViewItem];
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
}

- (void)refreshPreviews:(id)sender {
    CGSize filterSize = CGSizeMake(40, 40);
    CGSize thumbnailSize = CGSizeMake(294, 250);
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        CFArrayRef windowCGArray = CGWindowListCopyWindowInfo(kCGWindowListExcludeDesktopElements, kCGNullWindowID);
        NSArray *windowArray = CFBridgingRelease(windowCGArray);
        
        NSMutableArray *filteredArray = [NSMutableArray array];
        
        for (NSUInteger i = 0; i < windowArray.count; i++) {
            NSMutableDictionary *windowDict = [windowArray[i] mutableCopy];
            NSString *bundleId = [NSRunningApplication runningApplicationWithProcessIdentifier:[windowDict[(NSString *)kCGWindowOwnerPID] intValue]].bundleIdentifier;
            if (bundleId) {
                windowDict[@"kCGWindowOwnerBundleID"] = bundleId;
            }
            
            NSDictionary *boundsDict = windowDict[(NSString *)kCGWindowBounds];
            CGRect bounds;
            CGRectMakeWithDictionaryRepresentation((__bridge CFDictionaryRef)boundsDict, &bounds);
            
            if ((bounds.size.width <= filterSize.width) || (bounds.size.height <= filterSize.height)) {
                continue;
            }
            
            CGWindowID windowID = [windowDict[(NSString *)kCGWindowNumber] unsignedIntValue];
            
            CGImageRef windowImageTest = CGWindowListCreateImage(CGRectMake(filterSize.width - 1, filterSize.height - 1, 2, 2), kCGWindowListOptionIncludingWindow, windowID, kCGWindowImageDefault);
            if ((CGImageGetHeight(windowImageTest) <= 1) || (CGImageGetWidth(windowImageTest) <= 1)) {
                CGImageRelease(windowImageTest);
                continue;
            }
            CGImageRelease(windowImageTest);

            CGImageRef windowImage = CGWindowListCreateImage(bounds, kCGWindowListOptionIncludingWindow, windowID, kCGWindowImageDefault);
            
            CGImageRef resizedCGImage = [self resizeImage_uikit:windowImage size:thumbnailSize];
//            CGImageRef resizedCGImage = [self resizeImage_vImage:windowImage size:CGSizeMake(294, 250)];

            NSImage *image;
            
            if (windowImage != NULL) {
                if (resizedCGImage) {
                    CGImageRelease(windowImage);
                    windowImage = resizedCGImage;
                }
                NSBitmapImageRep *bitmapRep = [[NSBitmapImageRep alloc] initWithCGImage:windowImage];
                image = [[NSImage alloc] init];
                [image addRepresentation:bitmapRep];
            }
            
            CGImageRelease(windowImage);
            
            if (!image) {
                continue;
            }
            
            windowDict[@"kCGWindowImage"] = image;
            
            [filteredArray addObject:windowDict];
        }
        
        NSComparator sortByBundleId = ^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
            NSDictionary *dic1 = obj1;
            NSDictionary *dic2 = obj2;
            NSString *str1 = dic1[@"kCGWindowOwnerBundleID"];
            NSString *str2 = dic2[@"kCGWindowOwnerBundleID"];
            return [str1 compare:str2];
        };
        
        [filteredArray sortUsingComparator:sortByBundleId];
        
        self.contents = filteredArray;

        dispatch_async(dispatch_get_main_queue(), ^{
            [self.collectionView setValue:@(0) forKey:@"_animationDuration"];
            [self.collectionView setContent:self.contents];
        });

    });
}

- (CGImageRef) resizeImage_vImage:(CGImageRef)windowImage size:(CGSize)size {
    // accelerated framework image resize blackmagic
    CGSize origSize = CGSizeMake(CGImageGetWidth(windowImage), CGImageGetHeight(windowImage));
    
    CGFloat scale = size.height / origSize.height;
    if (origSize.width * scale > size.width) {
        scale = size.width / origSize.height;
    }
    CGSize resSize = CGSizeMake(origSize.width * scale, origSize.height * scale);
    
    CGColorSpaceRef originalColorSpace = CGColorSpaceRetain(CGImageGetColorSpace(windowImage));

    vImage_CGImageFormat vImFormat = {
        .bitsPerComponent = 8,
        .bitsPerPixel = 32,
        .colorSpace = originalColorSpace,
        .bitmapInfo = CGImageGetBitmapInfo(windowImage),
        .version = 0,
        .decode = NULL,
        .renderingIntent = kCGRenderingIntentDefault};
    
    vImage_Buffer vImSrcBuffer;
    
    vImage_Error vImError = vImageBuffer_InitWithCGImage(&vImSrcBuffer, &vImFormat, NULL, windowImage, kvImageNoFlags);
    if (vImError != kvImageNoError) {
        NSLog(@"vImageBuffer_InitWithCGImage vImage_Error %@", @(vImError));
        return nil;
    }
    
    vImage_Buffer vImDstBuffer;
    
    vImError = vImageBuffer_Init(&vImDstBuffer, resSize.height, resSize.width, vImFormat.bitsPerPixel, kvImageNoFlags);
    if (vImError != kvImageNoError) {
        NSLog(@"vImageBuffer_Init vImage_Error %@", @(vImError));
        return nil;
    }
    
    vImError = vImageScale_ARGB8888(&vImSrcBuffer, &vImDstBuffer, nil, kvImageDoNotTile);
    if (vImError != kvImageNoError) {
        NSLog(@"vImageScale_ARGB8888 vImage_Error %@", @(vImError));
        return nil;
    }

    CGImageRef resizedCGImage = vImageCreateCGImageFromBuffer(&vImDstBuffer, &vImFormat, nil, nil, kvImageNoAllocate, &vImError);
    if (vImError != kvImageNoError) {
        NSLog(@"vImageCreateCGImageFromBuffer vImage_Error %@", @(vImError));
        return nil;
    }
    
    CGColorSpaceRelease(originalColorSpace);
    free(vImSrcBuffer.data);

    return resizedCGImage;
}

- (CGImageRef) resizeImage_uikit:(CGImageRef)windowImage size:(CGSize)size {
    CGSize origSize = CGSizeMake(CGImageGetWidth(windowImage), CGImageGetHeight(windowImage));
    
    CGFloat scale = size.height / origSize.height;
    if (origSize.width * scale > size.width) {
        scale = size.width / origSize.height;
    }
    CGSize resSize = CGSizeMake(origSize.width * scale, origSize.height * scale);

    CGColorSpaceRef originalColorSpace = CGColorSpaceRetain(CGImageGetColorSpace(windowImage));

    CGContextRef context = CGBitmapContextCreate(nil, (size_t)resSize.width, (size_t)resSize.height, CGImageGetBitsPerComponent(windowImage), CGImageGetBytesPerRow(windowImage), originalColorSpace, CGImageGetBitmapInfo(windowImage));
    
    CGContextSetInterpolationQuality(context, kCGInterpolationLow);
    
    CGContextDrawImage(context, CGRectMake(0, 0, resSize.width, resSize.height), windowImage);
    
    CGImageRef resizedCGImage = CGBitmapContextCreateImage(context);
    
    CGColorSpaceRelease(originalColorSpace);
    CGContextRelease(context);
    return resizedCGImage;
}


@end
