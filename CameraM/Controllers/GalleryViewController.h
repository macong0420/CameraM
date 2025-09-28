//
//  GalleryViewController.h
//  CameraM
//
//  Created by OpenAI Assistant on 2025/9/28.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@class GalleryViewController;

@protocol GalleryViewControllerDelegate <NSObject>

- (void)galleryViewControllerDidCancel:(GalleryViewController *)controller;
- (void)galleryViewController:(GalleryViewController *)controller
                 didSelectImage:(UIImage *)image;

@end

@interface GalleryViewController : UIViewController

@property(nonatomic, weak) id<GalleryViewControllerDelegate> delegate;

@end

NS_ASSUME_NONNULL_END
