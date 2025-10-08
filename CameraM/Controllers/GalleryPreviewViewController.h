//
//  GalleryPreviewViewController.h
//  CameraM
//
//  Created by OpenAI Assistant on 2025/10/6.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@class GalleryPreviewViewController;

@protocol GalleryPreviewViewControllerDelegate <NSObject>

- (void)galleryPreviewViewControllerDidRequestContinue:
    (GalleryPreviewViewController *)controller;
- (void)galleryPreviewViewControllerDidRequestEdit:
    (GalleryPreviewViewController *)controller;

@end

@interface GalleryPreviewViewController : UIViewController

- (instancetype)initWithImage:(UIImage *)image
                     metadata:(NSDictionary *_Nullable)metadata
    NS_DESIGNATED_INITIALIZER;

- (instancetype)initWithImage:(UIImage *)image;

@property(nonatomic, weak) id<GalleryPreviewViewControllerDelegate> delegate;
@property(nonatomic, strong, readonly) UIImage *image;
@property(nonatomic, strong, readonly, nullable) NSDictionary *metadata;

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithCoder:(NSCoder *)coder NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
