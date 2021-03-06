//
//  Snapshooter.m
//  Pods
//
//  Created by Seiya Shimokawa on 10/8/15.
//
//

#import "Snapshooter.h"
#import "PKMainViewController.h"
#import "PKMarkableImageView.h"
#import <ImageIO/ImageIO.h>
#import <MobileCoreServices/UTCoreTypes.h>

@interface Snapshooter () <UIGestureRecognizerDelegate, UIActivityItemSource, PKMainViewControllerDelegate>
@property (nonatomic, weak) UIWindow *window;
@property (nonatomic) UIWindow *pkWindow;
@property (nonatomic) NSDictionary *properties;
@property (nonatomic) UIImage *shareThumbnailImage;
@property (nonatomic) NSData *shareImageData;
@property (nonatomic) UIInterfaceOrientation currentOrientation;
@end

@implementation Snapshooter

#pragma mark - public

+ (void)enableWithProperties:(NSDictionary *)properties {
    dispatch_async(dispatch_get_main_queue(), ^{
        [[Snapshooter sharedShooter] setupWindow];
        [Snapshooter sharedShooter].properties = properties;
    });
}

+ (UIInterfaceOrientationMask)supportedInterfaceOrientationsForWindow:(UIWindow *)window {
    if ([UIApplication sharedApplication].keyWindow == [Snapshooter sharedShooter].pkWindow) {
        switch ([Snapshooter sharedShooter].currentOrientation) {
            case UIInterfaceOrientationPortrait:
                return UIInterfaceOrientationMaskPortrait;
            case UIInterfaceOrientationPortraitUpsideDown:
                return UIInterfaceOrientationMaskPortraitUpsideDown;
            case UIInterfaceOrientationLandscapeLeft:
                return UIInterfaceOrientationMaskLandscapeLeft;
            case UIInterfaceOrientationLandscapeRight:
                return UIInterfaceOrientationMaskLandscapeRight;
            default:
                return UIInterfaceOrientationMaskPortrait;
        }
    }
    
    NSArray *supportedOrientations = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"UISupportedInterfaceOrientations"];
    NSUInteger orientationMask = 0;
    for (NSString *orientation in supportedOrientations) {
        if ([orientation isEqualToString:@"UIInterfaceOrientationPortrait"]) {
            orientationMask |= UIInterfaceOrientationMaskPortrait;
        }
        else if ([orientation isEqualToString:@"UIInterfaceOrientationPortraitUpsideDown"]) {
            orientationMask |= UIInterfaceOrientationMaskPortraitUpsideDown;
        }
        else if ([orientation isEqualToString:@"UIInterfaceOrientationLandscapeLeft"]) {
            orientationMask |= UIInterfaceOrientationMaskLandscapeLeft;
        }
        else if ([orientation isEqualToString:@"UIInterfaceOrientationLandscapeRight"]) {
            orientationMask |= UIInterfaceOrientationMaskLandscapeRight;
        }
    }
    return orientationMask;
}

#pragma mark - private

+ (instancetype)sharedShooter {
    static Snapshooter *shooter;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shooter = [[Snapshooter alloc] init];
    });
    return shooter;
}

- (instancetype)init {
    if (self = [super init]) {
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(windowDidBecomeKeyNotification:) name:UIWindowDidBecomeKeyNotification object:nil];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)setupWindow {
    if (self.window) return;
    
    self.window = [UIApplication sharedApplication].keyWindow;
    if (!self.window) self.window = [UIApplication sharedApplication].windows.lastObject;
    if (!self.window) [[NSException exceptionWithName:NSGenericException reason:@"Snapshotter no windows" userInfo:nil] raise];
    if (!self.window.rootViewController) [[NSException exceptionWithName:NSGenericException reason:@"Snapshotter no rootViewController on the window" userInfo:nil] raise];
    
    [self addGestureToWindow:self.window];
}

- (void)addGestureToWindow:(UIWindow *)window {
    UISwipeGestureRecognizer *gestureRecognizer = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(swipeGestureRecognized:)];
#if TARGET_IPHONE_SIMULATOR
    gestureRecognizer.numberOfTouchesRequired = 1;
#else
    gestureRecognizer.numberOfTouchesRequired = 2;
#endif
    gestureRecognizer.direction = UISwipeGestureRecognizerDirectionUp;
    gestureRecognizer.delegate = self;
    [window addGestureRecognizer:gestureRecognizer];
}

#pragma mark - selector

- (void)windowDidBecomeKeyNotification:(NSNotification *)notification {
    UIWindow *window = (UIWindow *)notification.object;
    if (!window || ![window isKindOfClass:UIWindow.class] || window == self.pkWindow) return;
    
    self.window = window;
    [self addGestureToWindow:window];
}

- (void)swipeGestureRecognized:(UISwipeGestureRecognizer *)recognizer {
    UIViewController *currentViewController = self.window.rootViewController;
    while (currentViewController.presentedViewController)
        currentViewController = currentViewController.presentedViewController;
    
    CGPoint location = [recognizer locationInView:currentViewController.view];
    if ((location.y + CGRectGetMinY(currentViewController.view.frame)) < (CGRectGetHeight(self.window.bounds) - 64)) return;
    
    if ([UIApplication sharedApplication].keyWindow == self.pkWindow) return;
    self.currentOrientation = [UIApplication sharedApplication].statusBarOrientation;
    
    CGSize size = CGSizeMake(CGRectGetWidth(self.window.bounds), CGRectGetHeight(self.window.bounds));
    UIGraphicsBeginImageContextWithOptions(size, NO, [UIScreen mainScreen].scale);
    for (UIWindow *window in [UIApplication sharedApplication].windows) {
        CGRect frame = self.window.rootViewController.view.frame;
        [window drawViewHierarchyInRect:CGRectMake(0, 0, CGRectGetWidth(frame) - CGRectGetMinX(frame), CGRectGetHeight(frame) - CGRectGetMinY(frame)) afterScreenUpdates:NO];
    }
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    self.pkWindow = [[UIWindow alloc] initWithFrame:self.window.bounds];
    self.pkWindow.windowLevel = UIWindowLevelStatusBar;
    [self.pkWindow makeKeyAndVisible];
    
    PKMainViewController *mainViewController = [UIStoryboard storyboardWithName:@"Snapshooter" bundle:[NSBundle bundleForClass:[self class]]].instantiateInitialViewController;
    [mainViewController.snapshotImageView setImage:image];
    mainViewController.delegate = self;
    
    self.pkWindow.rootViewController = mainViewController;
}

#pragma mark - PKMainViewControllerDelegate

- (void)mainViewControllerDidTouchUpLeftButton {
    PKMainViewController *mainViewController = (PKMainViewController *)self.pkWindow.rootViewController;
    [UIView animateWithDuration:0.3 delay:0 options:UIViewAnimationOptionCurveEaseIn animations:^{
        mainViewController.view.alpha = 0;
    } completion:^(BOOL finished) {
        [self.window makeKeyAndVisible];
        self.pkWindow = nil;
    }];
}

- (void)mainViewControllerDidTouchUpRightButton {
    PKMainViewController *mainViewController = (PKMainViewController *)self.pkWindow.rootViewController;
    
    // create share data
    UIImageView *imageView = mainViewController.snapshotImageView;
    UIImage *image = imageView.image;
    CGSize size = CGSizeMake(image.size.width, image.size.height);
    UIGraphicsBeginImageContext(size);
    [imageView drawViewHierarchyInRect:CGRectMake(0, 0, size.width, size.height) afterScreenUpdates:NO];
    self.shareImageData = UIImagePNGRepresentation(UIGraphicsGetImageFromCurrentImageContext());
    UIGraphicsEndImageContext();
    
    // create thumbnail data
    size = CGSizeMake(CGRectGetWidth(imageView.bounds), CGRectGetHeight(imageView.bounds));
    UIGraphicsBeginImageContext(size);
    [imageView drawViewHierarchyInRect:CGRectMake(0, 0, size.width, size.height) afterScreenUpdates:NO];
    self.shareThumbnailImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    NSArray *activityItems = @[self];
    UIActivityViewController *activityViewController = [[UIActivityViewController alloc] initWithActivityItems:activityItems applicationActivities:nil];
    [mainViewController presentViewController:activityViewController animated:YES completion:nil];
    activityViewController.completionWithItemsHandler = ^(NSString * __nullable activityType, BOOL completed, NSArray * __nullable returnedItems, NSError * __nullable activityError) {
        if (completed) {
            [self mainViewControllerDidTouchUpLeftButton];
        }
    };
}

#pragma mark - UIGestureRecognizerDelegate

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    return YES;
}

#pragma mark - UIActivityItemSource

- (id)activityViewControllerPlaceholderItem:(UIActivityViewController *)activityViewController {
    return self.shareImageData;
}

- (nullable id)activityViewController:(UIActivityViewController *)activityViewController itemForActivityType:(NSString *)activityType {
    if ([activityType isEqualToString:@"ep.com.goodpatch.goodhub2.shareExtension"]) {
        return @{@"image":self.shareImageData,
                 @"key":self.properties[SnapshotterKeyShareKey]? : @""};
    }
    return self.shareImageData;
}

- (nullable UIImage *)activityViewController:(UIActivityViewController *)activityViewController thumbnailImageForActivityType:(nullable NSString *)activityType suggestedSize:(CGSize)size {
    return self.shareThumbnailImage;
}

@end
