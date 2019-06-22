
#import "PreviewCollectionItem.h"

@interface PreviewCollectionItem ()
@property (weak) IBOutlet NSImageView *imageView;
@property (weak) IBOutlet NSBox *boxView;
@property (strong) NSDictionary *windowDict;

@end

@implementation PreviewCollectionItem

-(void)setRepresentedObject:(id)representedObject{
    [super setRepresentedObject:representedObject];
    if (representedObject != nil) {
        self.windowDict = representedObject;

        NSString *bundleId = self.windowDict[@"kCGWindowOwnerBundleID"];
        NSNumber *windowId = self.windowDict[@"kCGWindowNumber"];
        NSString *name = self.windowDict[(NSString *)kCGWindowName];
        NSString *ownName = self.windowDict[(NSString *)kCGWindowOwnerName];
        NSDictionary *boundsDict = self.windowDict[(NSString *)kCGWindowBounds];
        CGRect bounds;
        CGRectMakeWithDictionaryRepresentation((__bridge CFDictionaryRef)boundsDict, &bounds);
        NSString *isOnscreen = [self.windowDict[(NSString *)kCGWindowIsOnscreen] boolValue]?@"[+]":@"[-]";
        NSString *alpha = [NSString stringWithFormat:@"[%@]", @([self.windowDict[(NSString *)kCGWindowAlpha] floatValue])];
        NSString *sharingState = @[@"[N]", @"[R]", @"[RW]"][[self.windowDict[(NSString *)kCGWindowSharingState] integerValue]];

        NSImage *image = self.windowDict[@"kCGWindowImage"];
        self.boxView.title = [NSString stringWithFormat:@"%@ [%@]\n%@x%@@%@,%@ - %@x%@ %@%@%@\n[%@] %@", bundleId, windowId, @(bounds.size.width), @(bounds.size.height), @(bounds.origin.x), @(bounds.origin.y), @(image.size.width), @(image.size.height), isOnscreen, alpha, sharingState, ownName, name];
        self.imageView.image = image;
        
    } else {
        self.boxView.title = @"";
    }
}

@end
