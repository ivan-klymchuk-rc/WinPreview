
#import "AppDelegate.h"
#import "PreviewCollectionItem.h"

@interface AppDelegate ()

@property (weak) IBOutlet NSWindow *window;
@property (strong) NSArray *contents;
@property (assign) IBOutlet NSCollectionView *collectionView;
@property (strong) PreviewCollectionItem *collectionViewItem;
@property (strong) NSTimer *timer;

@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    self.timer = [NSTimer scheduledTimerWithTimeInterval:1.0
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
        
        if ((bounds.size.width <= 40) || (bounds.size.height <= 40)) {
            continue;
        }
        
        CGWindowID windowID = [windowDict[(NSString *)kCGWindowNumber] unsignedIntValue];
        CGImageRef windowImage = CGWindowListCreateImage(bounds, kCGWindowListOptionIncludingWindow, windowID, kCGWindowImageDefault);

        if ((CGImageGetHeight(windowImage) <= 40) || (CGImageGetWidth(windowImage) <= 40)) {
            CGImageRelease(windowImage);
            continue;
        }

        NSImage *image;
        
        if (windowImage != NULL) {
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
    
    [self.collectionView setValue:@(0) forKey:@"_animationDuration"];
    [self.collectionView setContent:self.contents];
}

@end
