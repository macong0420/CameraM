//
//  GalleryViewController.m
//  CameraM
//
//  Created by OpenAI Assistant on 2025/9/28.
//

#import "GalleryViewController.h"
#import <Photos/Photos.h>

static NSString *const kGalleryCellReuseIdentifier = @"GalleryCell";

@interface GalleryImageCell : UICollectionViewCell
@property(nonatomic, strong) UIImageView *imageView;
@property(nonatomic, copy) NSString *representedAssetIdentifier;
@end

@implementation GalleryImageCell

- (instancetype)initWithFrame:(CGRect)frame {
  self = [super initWithFrame:frame];
  if (self) {
    _imageView = [[UIImageView alloc] initWithFrame:self.contentView.bounds];
    _imageView.translatesAutoresizingMaskIntoConstraints = NO;
    _imageView.contentMode = UIViewContentModeScaleAspectFill;
    _imageView.clipsToBounds = YES;
    [self.contentView addSubview:_imageView];

    [NSLayoutConstraint activateConstraints:@[
      [_imageView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor],
      [_imageView.leadingAnchor
          constraintEqualToAnchor:self.contentView.leadingAnchor],
      [_imageView.trailingAnchor
          constraintEqualToAnchor:self.contentView.trailingAnchor],
      [_imageView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor]
    ]];

    self.contentView.backgroundColor = [UIColor colorWithWhite:0.1 alpha:1.0];
  }
  return self;
}

- (void)prepareForReuse {
  [super prepareForReuse];
  self.imageView.image = nil;
  self.representedAssetIdentifier = nil;
}

@end

@interface GalleryViewController () <UICollectionViewDataSource,
                                     UICollectionViewDelegateFlowLayout>

@property(nonatomic, strong) UICollectionView *collectionView;
@property(nonatomic, strong) UIView *headerView;
@property(nonatomic, strong) UILabel *titleLabel;
@property(nonatomic, strong) UIButton *closeButton;
@property(nonatomic, strong) UILabel *emptyLabel;
@property(nonatomic, strong) UIActivityIndicatorView *loadingIndicator;
@property(nonatomic, strong) PHFetchResult<PHAsset *> *assets;
@property(nonatomic, strong) PHCachingImageManager *imageManager;
@property(nonatomic, assign) CGSize thumbnailSize;
@property(nonatomic, assign) BOOL isLoadingSelection;

@end

@implementation GalleryViewController

- (void)viewDidLoad {
  [super viewDidLoad];

  self.view.backgroundColor = [UIColor blackColor];
  self.imageManager = [[PHCachingImageManager alloc] init];
  self.thumbnailSize = CGSizeZero;

  [self setupHeader];
  [self setupCollectionView];
  [self setupEmptyState];
  [self setupLoadingIndicator];
  [self fetchAssets];
}

- (void)viewDidLayoutSubviews {
  [super viewDidLayoutSubviews];
  [self updateItemSizeIfNeeded];
}

#pragma mark - UI Setup

- (void)setupHeader {
  self.headerView = [[UIView alloc] init];
  self.headerView.translatesAutoresizingMaskIntoConstraints = NO;
  self.headerView.backgroundColor = [UIColor colorWithWhite:0.05 alpha:0.9];
  [self.view addSubview:self.headerView];

  self.titleLabel = [[UILabel alloc] init];
  self.titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
  self.titleLabel.text = @"相册";
  self.titleLabel.font = [UIFont systemFontOfSize:18 weight:UIFontWeightSemibold];
  self.titleLabel.textColor = [UIColor whiteColor];
  [self.headerView addSubview:self.titleLabel];

  self.closeButton = [UIButton buttonWithType:UIButtonTypeSystem];
  self.closeButton.translatesAutoresizingMaskIntoConstraints = NO;
  UIImage *closeImage = nil;
  if (@available(iOS 13.0, *)) {
    closeImage = [UIImage systemImageNamed:@"xmark"];
  }
  if (closeImage) {
    [self.closeButton setImage:closeImage forState:UIControlStateNormal];
  } else {
    [self.closeButton setTitle:@"关闭" forState:UIControlStateNormal];
    self.closeButton.titleLabel.font =
        [UIFont systemFontOfSize:16 weight:UIFontWeightRegular];
  }
  self.closeButton.tintColor = [UIColor whiteColor];
  self.closeButton.accessibilityLabel = NSLocalizedString(@"关闭", nil);
  [self.closeButton addTarget:self
                       action:@selector(handleCloseTapped)
             forControlEvents:UIControlEventTouchUpInside];
  [self.headerView addSubview:self.closeButton];

  UILayoutGuide *guide = self.view.safeAreaLayoutGuide;
  [NSLayoutConstraint activateConstraints:@[
    [self.headerView.topAnchor constraintEqualToAnchor:guide.topAnchor],
    [self.headerView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
    [self.headerView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
    [self.headerView.heightAnchor constraintEqualToConstant:56.0],

    [self.titleLabel.centerXAnchor constraintEqualToAnchor:self.headerView.centerXAnchor],
    [self.titleLabel.centerYAnchor constraintEqualToAnchor:self.headerView.centerYAnchor],

    [self.closeButton.centerYAnchor constraintEqualToAnchor:self.headerView.centerYAnchor],
    [self.closeButton.trailingAnchor
        constraintEqualToAnchor:self.headerView.trailingAnchor
                       constant:-16.0]
  ]];
}

- (void)setupCollectionView {
  UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
  layout.minimumInteritemSpacing = 1.0f;
  layout.minimumLineSpacing = 1.0f;

  self.collectionView = [[UICollectionView alloc] initWithFrame:CGRectZero
                                           collectionViewLayout:layout];
  self.collectionView.translatesAutoresizingMaskIntoConstraints = NO;
  self.collectionView.backgroundColor = [UIColor blackColor];
  self.collectionView.dataSource = self;
  self.collectionView.delegate = self;
  self.collectionView.alwaysBounceVertical = YES;
  [self.collectionView registerClass:[GalleryImageCell class]
          forCellWithReuseIdentifier:kGalleryCellReuseIdentifier];
  [self.view addSubview:self.collectionView];

  [NSLayoutConstraint activateConstraints:@[
    [self.collectionView.topAnchor
        constraintEqualToAnchor:self.headerView.bottomAnchor],
    [self.collectionView.leadingAnchor
        constraintEqualToAnchor:self.view.leadingAnchor],
    [self.collectionView.trailingAnchor
        constraintEqualToAnchor:self.view.trailingAnchor],
    [self.collectionView.bottomAnchor
        constraintEqualToAnchor:self.view.bottomAnchor]
  ]];
}

- (void)setupEmptyState {
  self.emptyLabel = [[UILabel alloc] init];
  self.emptyLabel.translatesAutoresizingMaskIntoConstraints = NO;
  self.emptyLabel.text = @"暂无照片";
  self.emptyLabel.textColor = [UIColor colorWithWhite:1.0 alpha:0.6];
  self.emptyLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightMedium];
  self.emptyLabel.hidden = YES;
  [self.view addSubview:self.emptyLabel];

  [NSLayoutConstraint activateConstraints:@[
    [self.emptyLabel.centerXAnchor constraintEqualToAnchor:self.collectionView.centerXAnchor],
    [self.emptyLabel.centerYAnchor constraintEqualToAnchor:self.collectionView.centerYAnchor]
  ]];
}

- (void)setupLoadingIndicator {
  self.loadingIndicator = [[UIActivityIndicatorView alloc]
      initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleLarge];
  self.loadingIndicator.translatesAutoresizingMaskIntoConstraints = NO;
  self.loadingIndicator.hidesWhenStopped = YES;
  self.loadingIndicator.color = [UIColor whiteColor];
  [self.view addSubview:self.loadingIndicator];

  [NSLayoutConstraint activateConstraints:@[
    [self.loadingIndicator.centerXAnchor
        constraintEqualToAnchor:self.collectionView.centerXAnchor],
    [self.loadingIndicator.centerYAnchor
        constraintEqualToAnchor:self.collectionView.centerYAnchor]
  ]];
}

#pragma mark - Data

- (void)fetchAssets {
  [self.loadingIndicator startAnimating];

  dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
    PHFetchOptions *options = [[PHFetchOptions alloc] init];
    options.sortDescriptors = @[ [NSSortDescriptor sortDescriptorWithKey:@"creationDate"
                                                                ascending:NO] ];
    options.predicate = [NSPredicate predicateWithFormat:@"mediaType == %d",
                                                    PHAssetMediaTypeImage];
    PHFetchResult<PHAsset *> *result =
        [PHAsset fetchAssetsWithMediaType:PHAssetMediaTypeImage
                                   options:options];

    dispatch_async(dispatch_get_main_queue(), ^{
      self.assets = result;
      [self.collectionView reloadData];
      [self.loadingIndicator stopAnimating];
      self.emptyLabel.hidden = (result.count != 0);
    });
  });
}

#pragma mark - Actions

- (void)handleCloseTapped {
  if ([self.delegate respondsToSelector:@selector(galleryViewControllerDidCancel:)]) {
    [self.delegate galleryViewControllerDidCancel:self];
  }
}

#pragma mark - Helpers

- (void)updateItemSizeIfNeeded {
  UICollectionViewFlowLayout *layout =
      (UICollectionViewFlowLayout *)self.collectionView.collectionViewLayout;
  CGFloat width = CGRectGetWidth(self.collectionView.bounds);
  if (width <= 0) {
    return;
  }

  BOOL isLandscape = CGRectGetWidth(self.view.bounds) > CGRectGetHeight(self.view.bounds);
  NSInteger columns = isLandscape ? 5 : 3;
  CGFloat spacing = layout.minimumInteritemSpacing;
  CGFloat totalSpacing = (columns - 1) * spacing;
  CGFloat itemWidth = floor((width - totalSpacing) / (CGFloat)columns);
  CGSize newSize = CGSizeMake(itemWidth, itemWidth);

  if (!CGSizeEqualToSize(newSize, layout.itemSize)) {
    layout.itemSize = newSize;
    self.thumbnailSize = newSize;
    [layout invalidateLayout];
  }
}

- (void)showImageLoadFailure {
  UIAlertController *alert =
      [UIAlertController alertControllerWithTitle:@"无法打开照片"
                                          message:@"加载所选照片失败，请稍后重试。"
                                   preferredStyle:UIAlertControllerStyleAlert];
  UIAlertAction *confirm =
      [UIAlertAction actionWithTitle:@"确定"
                               style:UIAlertActionStyleDefault
                             handler:nil];
  [alert addAction:confirm];
  [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - UICollectionViewDataSource

- (NSInteger)collectionView:(UICollectionView *)collectionView
     numberOfItemsInSection:(NSInteger)section {
  return self.assets.count;
}

- (__kindof UICollectionViewCell *)collectionView:
                                         (UICollectionView *)collectionView
                           cellForItemAtIndexPath:(NSIndexPath *)indexPath {
  GalleryImageCell *cell =
      [collectionView dequeueReusableCellWithReuseIdentifier:kGalleryCellReuseIdentifier
                                                forIndexPath:indexPath];

  if (indexPath.item >= self.assets.count) {
    cell.imageView.image = nil;
    cell.representedAssetIdentifier = nil;
    return cell;
  }

  PHAsset *asset = self.assets[indexPath.item];
  cell.representedAssetIdentifier = asset.localIdentifier;

  CGFloat scale = UIScreen.mainScreen.scale;
  CGSize targetSize =
      CGSizeMake(self.thumbnailSize.width * scale, self.thumbnailSize.height * scale);

  PHImageRequestOptions *options = [[PHImageRequestOptions alloc] init];
  options.resizeMode = PHImageRequestOptionsResizeModeFast;
  options.deliveryMode = PHImageRequestOptionsDeliveryModeOpportunistic;
  options.networkAccessAllowed = YES;

  __weak GalleryImageCell *weakCell = cell;
  [self.imageManager requestImageForAsset:asset
                               targetSize:targetSize
                              contentMode:PHImageContentModeAspectFill
                                  options:options
                            resultHandler:^(UIImage *_Nullable result,
                                            NSDictionary *_Nullable info) {
                              dispatch_async(dispatch_get_main_queue(), ^{
                                GalleryImageCell *strongCell = weakCell;
                                if (!strongCell) {
                                  return;
                                }
                                BOOL matches =
                                    [strongCell.representedAssetIdentifier
                                        isEqualToString:asset.localIdentifier];
                                if (matches && result) {
                                  strongCell.imageView.image = result;
                                }
                              });
                            }];

  return cell;
}

#pragma mark - UICollectionViewDelegate

- (void)collectionView:(UICollectionView *)collectionView
    didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
  if (self.isLoadingSelection) {
    return;
  }
  if (indexPath.item >= self.assets.count) {
    return;
  }

  PHAsset *asset = self.assets[indexPath.item];
  self.isLoadingSelection = YES;
  [self.loadingIndicator startAnimating];
  self.collectionView.userInteractionEnabled = NO;

  PHImageRequestOptions *options = [[PHImageRequestOptions alloc] init];
  options.networkAccessAllowed = YES;
  options.deliveryMode = PHImageRequestOptionsDeliveryModeHighQualityFormat;
  options.resizeMode = PHImageRequestOptionsResizeModeNone;

  __weak typeof(self) weakSelf = self;
  [self.imageManager requestImageDataAndOrientationForAsset:asset
                                                    options:options
                                              resultHandler:^(NSData *_Nullable imageData,
                                                              NSString *_Nullable dataUTI,
                                                              CGImagePropertyOrientation orientation,
                                                              NSDictionary *_Nullable info) {
                                                dispatch_async(dispatch_get_main_queue(), ^{
                                                  __strong typeof(weakSelf) strongSelf =
                                                      weakSelf;
                                                  strongSelf.isLoadingSelection = NO;
                                                  [strongSelf.loadingIndicator stopAnimating];
                                                  strongSelf.collectionView.userInteractionEnabled = YES;

                                                  if (!strongSelf) {
                                                    return;
                                                  }

                                                  UIImage *image =
                                                      imageData ? [UIImage imageWithData:imageData] : nil;
                                                  if (image &&
                                                      [strongSelf.delegate
                                                          respondsToSelector:@selector
                                                          (galleryViewController:
                                                                               didSelectImage:)]) {
                                                    [strongSelf.delegate
                                                        galleryViewController:strongSelf
                                                               didSelectImage:image];
                                                  } else {
                                                    [strongSelf showImageLoadFailure];
                                                  }
                                                });
                                              }];
}

@end
