//
//  FilterPanelView.m
//  CameraM
//
//  Created by Generated on 2025/9/26.
//

#import "FilterPanelView.h"
#import "ARFilterDescriptor.h"
#import "ARFilterPipeline.h"
@import CoreImage;

@interface FilterCell : UICollectionViewCell
@property(nonatomic, strong) UIImageView *thumbnailView;
@property(nonatomic, strong) UILabel *nameLabel;
@property(nonatomic, strong) UIView *selectionIndicator;
@property(nonatomic, strong) NSMutableDictionary *thumbnailCache;
@property(nonatomic, strong) dispatch_queue_t thumbnailQueue;
@property(nonatomic, strong) UIImage *sampleImage;

- (void)createSampleImage;
- (void)setupUI;
@end

@implementation FilterCell

- (instancetype)initWithFrame:(CGRect)frame {
  if (self = [super initWithFrame:frame]) {
    _thumbnailCache = [NSMutableDictionary dictionary];
    _thumbnailQueue = dispatch_queue_create("com.cameram.filter.thumbnail",
                                            DISPATCH_QUEUE_CONCURRENT);
    [self createSampleImage];
    [self setupUI];
  }
  return self;
}

- (void)setupUI {
  self.thumbnailView = [[UIImageView alloc] init];
  self.thumbnailView.contentMode = UIViewContentModeScaleAspectFill;
  self.thumbnailView.clipsToBounds = YES;
  self.thumbnailView.layer.cornerRadius = 8;
  self.thumbnailView.backgroundColor = [UIColor colorWithWhite:0.2 alpha:1.0];
  self.thumbnailView.translatesAutoresizingMaskIntoConstraints = NO;
  [self.contentView addSubview:self.thumbnailView];

  self.nameLabel = [[UILabel alloc] init];
  self.nameLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightMedium];
  self.nameLabel.textColor = [UIColor whiteColor];
  self.nameLabel.textAlignment = NSTextAlignmentCenter;
  self.nameLabel.translatesAutoresizingMaskIntoConstraints = NO;
  [self.contentView addSubview:self.nameLabel];

  self.selectionIndicator = [[UIView alloc] init];
  self.selectionIndicator.backgroundColor = [UIColor systemOrangeColor];
  self.selectionIndicator.layer.cornerRadius = 10;
  self.selectionIndicator.hidden = YES;
  self.selectionIndicator.translatesAutoresizingMaskIntoConstraints = NO;
  [self.contentView addSubview:self.selectionIndicator];

  [NSLayoutConstraint activateConstraints:@[
    [self.thumbnailView.topAnchor
        constraintEqualToAnchor:self.contentView.topAnchor
                       constant:8],
    [self.thumbnailView.leadingAnchor
        constraintEqualToAnchor:self.contentView.leadingAnchor
                       constant:8],
    [self.thumbnailView.trailingAnchor
        constraintEqualToAnchor:self.contentView.trailingAnchor
                       constant:-8],
    [self.thumbnailView.heightAnchor constraintEqualToConstant:72],

    [self.nameLabel.topAnchor
        constraintEqualToAnchor:self.thumbnailView.bottomAnchor
                       constant:4],
    [self.nameLabel.leadingAnchor
        constraintEqualToAnchor:self.contentView.leadingAnchor],
    [self.nameLabel.trailingAnchor
        constraintEqualToAnchor:self.contentView.trailingAnchor],
    [self.nameLabel.bottomAnchor
        constraintEqualToAnchor:self.contentView.bottomAnchor
                       constant:-4],

    [self.selectionIndicator.topAnchor
        constraintEqualToAnchor:self.thumbnailView.topAnchor
                       constant:-2],
    [self.selectionIndicator.leadingAnchor
        constraintEqualToAnchor:self.thumbnailView.leadingAnchor
                       constant:-2],
    [self.selectionIndicator.trailingAnchor
        constraintEqualToAnchor:self.thumbnailView.trailingAnchor
                       constant:2],
    [self.selectionIndicator.bottomAnchor
        constraintEqualToAnchor:self.thumbnailView.bottomAnchor
                       constant:2]
  ]];
}

- (void)createSampleImage {
  // 创建一个简单的渐变样本图片用于滤镜预览
  CGSize size = CGSizeMake(72, 72);
  UIGraphicsBeginImageContextWithOptions(size, NO, 0);

  CGContextRef context = UIGraphicsGetCurrentContext();

  // 创建渐变
  CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
  NSArray *colors = @[
    (__bridge id)[UIColor colorWithRed:0.2 green:0.4 blue:0.8 alpha:1.0]
        .CGColor,
    (__bridge id)[UIColor colorWithRed:0.8 green:0.6 blue:0.2 alpha:1.0]
        .CGColor,
    (__bridge id)[UIColor colorWithRed:0.6 green:0.2 blue:0.8 alpha:1.0].CGColor
  ];

  CGGradientRef gradient =
      CGGradientCreateWithColors(colorSpace, (__bridge CFArrayRef)colors, NULL);
  CGContextDrawLinearGradient(context, gradient, CGPointMake(0, 0),
                              CGPointMake(size.width, size.height), 0);

  // 添加一些几何形状
  CGContextSetFillColorWithColor(context, [UIColor whiteColor].CGColor);
  CGContextFillEllipseInRect(context, CGRectMake(10, 10, 20, 20));
  CGContextFillRect(context, CGRectMake(40, 40, 20, 20));

  self.sampleImage = UIGraphicsGetImageFromCurrentImageContext();

  CGGradientRelease(gradient);
  CGColorSpaceRelease(colorSpace);
  UIGraphicsEndImageContext();
}

- (void)setSelected:(BOOL)selected {
  [super setSelected:selected];
  self.selectionIndicator.hidden = !selected;
}

@end

@interface FilterPanelView () <UICollectionViewDataSource,
                               UICollectionViewDelegate>
@property(nonatomic, strong) UICollectionView *collectionView;
@property(nonatomic, strong) UISlider *intensitySlider;
@property(nonatomic, strong) UILabel *intensityLabel;
@property(nonatomic, strong) NSArray<ARFilterDescriptor *> *filters;
@property(nonatomic, strong)
    NSMutableDictionary<NSString *, UIImage *> *thumbnailCache;
@property(nonatomic, strong) dispatch_queue_t thumbnailQueue;
@property(nonatomic, strong) UIImage *sampleImage;
@end

@implementation FilterPanelView

- (instancetype)initWithFrame:(CGRect)frame {
  if (self = [super initWithFrame:frame]) {
    self.thumbnailCache = [NSMutableDictionary dictionary];
    self.thumbnailQueue = dispatch_queue_create("com.cameram.filter.thumbnail",
                                                DISPATCH_QUEUE_CONCURRENT);
    [self createSampleImage];
    [self setupUI];
  }
  return self;
}

- (void)setupUI {
  self.backgroundColor = [UIColor colorWithWhite:0 alpha:0.8];

  // 强度标签
  self.intensityLabel = [[UILabel alloc] init];
  self.intensityLabel.text = @"强度";
  self.intensityLabel.font = [UIFont systemFontOfSize:14
                                               weight:UIFontWeightMedium];
  self.intensityLabel.textColor = [UIColor whiteColor];
  self.intensityLabel.translatesAutoresizingMaskIntoConstraints = NO;
  [self addSubview:self.intensityLabel];

  // 强度滑杆
  self.intensitySlider = [[UISlider alloc] init];
  self.intensitySlider.minimumValue = 0.0;
  self.intensitySlider.maximumValue = 1.0;
  self.intensitySlider.value = 1.0;
  self.intensitySlider.tintColor = [UIColor systemOrangeColor];
  [self.intensitySlider addTarget:self
                           action:@selector(intensityChanged:)
                 forControlEvents:UIControlEventValueChanged];
  self.intensitySlider.translatesAutoresizingMaskIntoConstraints = NO;
  [self addSubview:self.intensitySlider];

  // 滤镜集合视图
  UICollectionViewFlowLayout *layout =
      [[UICollectionViewFlowLayout alloc] init];
  layout.scrollDirection = UICollectionViewScrollDirectionHorizontal;
  layout.minimumLineSpacing = 12;
  layout.itemSize = CGSizeMake(88, 110);
  layout.sectionInset = UIEdgeInsetsMake(0, 16, 0, 16);

  self.collectionView = [[UICollectionView alloc] initWithFrame:CGRectZero
                                           collectionViewLayout:layout];
  self.collectionView.backgroundColor = [UIColor clearColor];
  self.collectionView.dataSource = self;
  self.collectionView.delegate = self;
  self.collectionView.showsHorizontalScrollIndicator = NO;
  [self.collectionView registerClass:[FilterCell class]
          forCellWithReuseIdentifier:@"FilterCell"];
  self.collectionView.translatesAutoresizingMaskIntoConstraints = NO;
  [self addSubview:self.collectionView];

  [NSLayoutConstraint activateConstraints:@[
    [self.intensityLabel.topAnchor constraintEqualToAnchor:self.topAnchor
                                                  constant:16],
    [self.intensityLabel.leadingAnchor
        constraintEqualToAnchor:self.leadingAnchor
                       constant:16],

    [self.intensitySlider.centerYAnchor
        constraintEqualToAnchor:self.intensityLabel.centerYAnchor],
    [self.intensitySlider.leadingAnchor
        constraintEqualToAnchor:self.intensityLabel.trailingAnchor
                       constant:12],
    [self.intensitySlider.trailingAnchor
        constraintEqualToAnchor:self.trailingAnchor
                       constant:-16],

    [self.collectionView.topAnchor
        constraintEqualToAnchor:self.intensitySlider.bottomAnchor
                       constant:16],
    [self.collectionView.leadingAnchor
        constraintEqualToAnchor:self.leadingAnchor],
    [self.collectionView.trailingAnchor
        constraintEqualToAnchor:self.trailingAnchor],
    [self.collectionView.bottomAnchor
        constraintEqualToAnchor:self.bottomAnchor],
    [self.collectionView.heightAnchor constraintEqualToConstant:130]
  ]];
}

- (void)updateWithFilters:(NSArray<ARFilterDescriptor *> *)filters {
  self.filters = filters;
  [self.collectionView reloadData];

  if (filters.count > 0) {
    self.currentFilter = filters.firstObject;
    [self.collectionView
        selectItemAtIndexPath:[NSIndexPath indexPathForItem:0 inSection:0]
                     animated:NO
               scrollPosition:UICollectionViewScrollPositionNone];
  }
}

- (void)setIntensity:(float)intensity {
  self.intensitySlider.value = intensity;
}

- (void)intensityChanged:(UISlider *)slider {
  if ([self.delegate respondsToSelector:@selector(didChangeFilterIntensity:)]) {
    [self.delegate didChangeFilterIntensity:slider.value];
  }
}

#pragma mark - UICollectionViewDataSource

- (NSInteger)collectionView:(UICollectionView *)collectionView
     numberOfItemsInSection:(NSInteger)section {
  return self.filters.count;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView
                  cellForItemAtIndexPath:(NSIndexPath *)indexPath {
  FilterCell *cell =
      [collectionView dequeueReusableCellWithReuseIdentifier:@"FilterCell"
                                                forIndexPath:indexPath];
  ARFilterDescriptor *filter = self.filters[indexPath.item];

  cell.nameLabel.text = filter.displayName;

  // 设置缩略图（异步生成）
  if (filter.thumbnail) {
    cell.thumbnailView.image = filter.thumbnail;
  } else {
    // 先设置占位图
    cell.thumbnailView.image = [self placeholderImageForFilter:filter];
    // 异步生成真实缩略图
    [self generateThumbnailForFilter:filter atIndexPath:indexPath];
  }

  return cell;
}

#pragma mark - UICollectionViewDelegate

- (void)collectionView:(UICollectionView *)collectionView
    didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
  ARFilterDescriptor *filter = self.filters[indexPath.item];
  self.currentFilter = filter;
  self.intensitySlider.value = filter.intensity;

  if ([self.delegate respondsToSelector:@selector(didSelectFilter:)]) {
    [self.delegate didSelectFilter:filter];
  }
}

- (UIImage *)placeholderImageForFilter:(ARFilterDescriptor *)filter {
  UIGraphicsBeginImageContextWithOptions(CGSizeMake(72, 72), NO, 0);
  [[UIColor colorWithWhite:0.3 alpha:1.0] setFill];
  UIRectFill(CGRectMake(0, 0, 72, 72));

  // 添加滤镜名称
  NSDictionary *attributes = @{
    NSFontAttributeName : [UIFont systemFontOfSize:10],
    NSForegroundColorAttributeName : [UIColor whiteColor]
  };
  CGSize textSize = [filter.displayName sizeWithAttributes:attributes];
  CGRect textRect =
      CGRectMake((72 - textSize.width) / 2, (72 - textSize.height) / 2,
                 textSize.width, textSize.height);
  [filter.displayName drawInRect:textRect withAttributes:attributes];

  UIImage *placeholderImage = UIGraphicsGetImageFromCurrentImageContext();
  UIGraphicsEndImageContext();

  return placeholderImage;
}

#pragma mark - 缩略图生成

- (void)createSampleImage {
  // 创建一个简单的渐变样本图片用于滤镜预览
  CGSize size = CGSizeMake(72, 72);
  UIGraphicsBeginImageContextWithOptions(size, NO, 0);

  CGContextRef context = UIGraphicsGetCurrentContext();

  // 创建渐变
  CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
  NSArray *colors = @[
    (__bridge id)[UIColor colorWithRed:0.2 green:0.4 blue:0.8 alpha:1.0]
        .CGColor,
    (__bridge id)[UIColor colorWithRed:0.8 green:0.6 blue:0.2 alpha:1.0]
        .CGColor,
    (__bridge id)[UIColor colorWithRed:0.6 green:0.2 blue:0.8 alpha:1.0].CGColor
  ];

  CGGradientRef gradient =
      CGGradientCreateWithColors(colorSpace, (__bridge CFArrayRef)colors, NULL);
  CGContextDrawLinearGradient(context, gradient, CGPointMake(0, 0),
                              CGPointMake(size.width, size.height), 0);

  // 添加一些几何形状
  CGContextSetFillColorWithColor(context, [UIColor whiteColor].CGColor);
  CGContextFillEllipseInRect(context, CGRectMake(10, 10, 20, 20));
  CGContextFillRect(context, CGRectMake(40, 40, 20, 20));

  self.sampleImage = UIGraphicsGetImageFromCurrentImageContext();

  CGGradientRelease(gradient);
  CGColorSpaceRelease(colorSpace);
  UIGraphicsEndImageContext();
}

- (void)generateThumbnailForFilter:(ARFilterDescriptor *)filter
                       atIndexPath:(NSIndexPath *)indexPath {
  if (!filter || !self.sampleImage) {
    return;
  }

  // 检查缓存
  UIImage *cachedThumbnail = self.thumbnailCache[filter.identifier];
  if (cachedThumbnail) {
    dispatch_async(dispatch_get_main_queue(), ^{
      [self updateCellAtIndexPath:indexPath withThumbnail:cachedThumbnail];
    });
    return;
  }

  __weak typeof(self) weakSelf = self;
  dispatch_async(self.thumbnailQueue, ^{
    @autoreleasepool {
      __strong typeof(weakSelf) strongSelf = weakSelf;
      if (!strongSelf)
        return;

      UIImage *thumbnail = [strongSelf generateThumbnailForFilter:filter];
      if (thumbnail) {
        // 缓存缩略图
        strongSelf.thumbnailCache[filter.identifier] = thumbnail;

        dispatch_async(dispatch_get_main_queue(), ^{
          [strongSelf updateCellAtIndexPath:indexPath withThumbnail:thumbnail];
        });
      }
    }
  });
}

- (UIImage *)generateThumbnailForFilter:(ARFilterDescriptor *)filter {
  if (!filter || !filter.pipeline || !self.sampleImage) {
    return nil;
  }

  // 对于原片滤镜，直接返回样本图片
  if ([filter.identifier isEqualToString:@"none"] ||
      [filter.identifier isEqualToString:@"original"]) {
    return self.sampleImage;
  }

  CIImage *inputImage = [CIImage imageWithCGImage:self.sampleImage.CGImage];
  if (!inputImage) {
    return nil;
  }

  // 设置滤镜强度为1.0以获得最佳预览效果
  filter.pipeline.intensity = 1.0f;

  // 应用滤镜
  CIImage *filteredImage = [filter.pipeline process:inputImage];
  if (!filteredImage) {
    return self.sampleImage;
  }

  // 转换为UIImage
  CIContext *context = [CIContext contextWithOptions:@{
    kCIContextUseSoftwareRenderer : @NO,
    kCIContextPriorityRequestLow : @YES
  }];

  CGImageRef cgImage = [context createCGImage:filteredImage
                                     fromRect:filteredImage.extent];
  if (!cgImage) {
    return self.sampleImage;
  }

  UIImage *thumbnail = [UIImage imageWithCGImage:cgImage];
  CGImageRelease(cgImage);

  return thumbnail ?: self.sampleImage;
}

- (void)updateCellAtIndexPath:(NSIndexPath *)indexPath
                withThumbnail:(UIImage *)thumbnail {
  FilterCell *cell =
      (FilterCell *)[self.collectionView cellForItemAtIndexPath:indexPath];
  if (cell && [cell isKindOfClass:[FilterCell class]]) {
    cell.thumbnailView.image = thumbnail;
  }
}

@end