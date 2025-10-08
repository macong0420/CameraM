//
//  GalleryPreviewViewController.m
//  CameraM
//
//  Created by OpenAI Assistant on 2025/10/6.
//

#import "GalleryPreviewViewController.h"

@interface GalleryPreviewViewController ()

@property(nonatomic, strong) UIImageView *imageView;
@property(nonatomic, strong) UIView *buttonContainer;
@property(nonatomic, strong) UIStackView *buttonStack;
@property(nonatomic, strong, readwrite) UIImage *image;
@property(nonatomic, strong, readwrite, nullable) NSDictionary *metadata;

@end

@implementation GalleryPreviewViewController

#pragma mark - Lifecycle

- (instancetype)initWithImage:(UIImage *)image
                     metadata:(NSDictionary *_Nullable)metadata {
  self = [super initWithNibName:nil bundle:nil];
  if (self) {
    _image = image ?: [[UIImage alloc] init];
    _metadata = [metadata copy];
    self.modalPresentationStyle = UIModalPresentationFullScreen;
    self.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
  }
  return self;
}

- (instancetype)initWithImage:(UIImage *)image {
  return [self initWithImage:image metadata:nil];
}

- (void)viewDidLoad {
  [super viewDidLoad];
  self.view.backgroundColor = [UIColor blackColor];
  [self setupImageView];
  [self setupButtonContainer];
}

- (BOOL)prefersStatusBarHidden {
  return YES;
}

#pragma mark - UI Setup

- (void)setupImageView {
  self.imageView = [[UIImageView alloc] initWithImage:self.image];
  self.imageView.translatesAutoresizingMaskIntoConstraints = NO;
  self.imageView.contentMode = UIViewContentModeScaleAspectFit;
  self.imageView.clipsToBounds = YES;
  [self.view addSubview:self.imageView];
}

- (void)setupButtonContainer {
  self.buttonContainer = [[UIView alloc] init];
  self.buttonContainer.translatesAutoresizingMaskIntoConstraints = NO;
  self.buttonContainer.backgroundColor = [UIColor colorWithWhite:0.05 alpha:0.9];
  [self.view addSubview:self.buttonContainer];

  UIView *separator = [[UIView alloc] init];
  separator.translatesAutoresizingMaskIntoConstraints = NO;
  separator.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.08];
  [self.buttonContainer addSubview:separator];

  UIButton *continueButton =
      [self actionButtonWithTitle:@"继续拍摄" primary:YES];
  [continueButton addTarget:self
                     action:@selector(handleContinueTapped)
           forControlEvents:UIControlEventTouchUpInside];

  UIButton *editButton = [self actionButtonWithTitle:@"编辑" primary:NO];
  [editButton addTarget:self
                 action:@selector(handleEditTapped)
       forControlEvents:UIControlEventTouchUpInside];

  self.buttonStack = [[UIStackView alloc] initWithArrangedSubviews:@[
    continueButton, editButton
  ]];
  self.buttonStack.translatesAutoresizingMaskIntoConstraints = NO;
  self.buttonStack.axis = UILayoutConstraintAxisHorizontal;
  self.buttonStack.alignment = UIStackViewAlignmentFill;
  self.buttonStack.distribution = UIStackViewDistributionFillEqually;
  self.buttonStack.spacing = 16.0f;
  [self.buttonContainer addSubview:self.buttonStack];

  UILayoutGuide *guide = self.view.safeAreaLayoutGuide;
  [NSLayoutConstraint activateConstraints:@[
    [self.buttonContainer.leadingAnchor
        constraintEqualToAnchor:self.view.leadingAnchor],
    [self.buttonContainer.trailingAnchor
        constraintEqualToAnchor:self.view.trailingAnchor],
    [self.buttonContainer.bottomAnchor
        constraintEqualToAnchor:self.view.bottomAnchor],

    [separator.topAnchor
        constraintEqualToAnchor:self.buttonContainer.topAnchor],
    [separator.leadingAnchor
        constraintEqualToAnchor:self.buttonContainer.leadingAnchor],
    [separator.trailingAnchor
        constraintEqualToAnchor:self.buttonContainer.trailingAnchor],
    [separator.heightAnchor constraintEqualToConstant:1.0],

    [self.buttonStack.topAnchor
        constraintEqualToAnchor:self.buttonContainer.topAnchor constant:20.0],
    [self.buttonStack.leadingAnchor
        constraintEqualToAnchor:self.buttonContainer.leadingAnchor
                       constant:24.0],
    [self.buttonStack.trailingAnchor
        constraintEqualToAnchor:self.buttonContainer.trailingAnchor
                       constant:-24.0],
    [self.buttonStack.bottomAnchor
        constraintEqualToAnchor:guide.bottomAnchor constant:-24.0],

    [self.imageView.topAnchor
        constraintEqualToAnchor:self.view.topAnchor],
    [self.imageView.leadingAnchor
        constraintEqualToAnchor:self.view.leadingAnchor],
    [self.imageView.trailingAnchor
        constraintEqualToAnchor:self.view.trailingAnchor],
    [self.imageView.bottomAnchor
        constraintEqualToAnchor:self.buttonContainer.topAnchor]
  ]];
}

- (UIButton *)actionButtonWithTitle:(NSString *)title primary:(BOOL)isPrimary {
  UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
  button.translatesAutoresizingMaskIntoConstraints = NO;
  [button setTitle:title forState:UIControlStateNormal];
  button.titleLabel.font =
      [UIFont systemFontOfSize:18.0 weight:UIFontWeightSemibold];
  button.layer.cornerRadius = 14.0f;
  button.layer.masksToBounds = YES;
  UIColor *backgroundColor =
      isPrimary ? [UIColor systemOrangeColor]
                : [UIColor colorWithWhite:1.0 alpha:0.16];
  UIColor *titleColor =
      isPrimary ? [UIColor blackColor] : [UIColor whiteColor];
  button.backgroundColor = backgroundColor;
  [button setTitleColor:titleColor forState:UIControlStateNormal];
  button.contentEdgeInsets = UIEdgeInsetsMake(14.0, 0.0, 14.0, 0.0);
  return button;
}

#pragma mark - Actions

- (void)handleContinueTapped {
  if ([self.delegate
          respondsToSelector:@selector
          (galleryPreviewViewControllerDidRequestContinue:)]) {
    [self.delegate galleryPreviewViewControllerDidRequestContinue:self];
  }
}

- (void)handleEditTapped {
  if ([self.delegate respondsToSelector:@selector
                     (galleryPreviewViewControllerDidRequestEdit:)]) {
    [self.delegate galleryPreviewViewControllerDidRequestEdit:self];
  }
}

@end
