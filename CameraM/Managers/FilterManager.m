//
//  FilterManager.m
//  CameraM
//
//  Created by Generated on 2025/9/26.
//

#import "FilterManager.h"
#import "ARFilterDescriptor.h"
#import "ARFilterFactory.h"
#import "ARFilterPipeline.h"

@interface FilterManager ()

@property(nonatomic, strong, readwrite)
    NSArray<ARFilterDescriptor *> *availableFilters;
@property(nonatomic, strong) CIContext *ciContext;

@end

@implementation FilterManager

+ (instancetype)sharedManager {
  static FilterManager *sharedInstance = nil;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    sharedInstance = [[FilterManager alloc] init];
  });
  return sharedInstance;
}

- (instancetype)init {
  self = [super init];
  if (self) {
    _intensity = 1.0f;
    _ciContext = [CIContext contextWithOptions:@{
      kCIContextUseSoftwareRenderer : @NO,
      kCIContextPriorityRequestLow : @NO
    }];
    [self loadDefaultFilters];
  }
  return self;
}

- (void)loadDefaultFilters {
  self.availableFilters = [ARFilterFactory defaultFilters];
  // 默认选择第一个滤镜（原片）
  if (self.availableFilters.count > 0) {
    self.currentFilter = self.availableFilters.firstObject;
  }
}

- (CIImage *)applyCurrentFilterToImage:(CIImage *)image {
  if (!image || !self.currentFilter) {
    return image;
  }

  // 设置管道强度
  self.currentFilter.pipeline.intensity = self.intensity;

  // 应用滤镜
  CIImage *filteredImage = [self.currentFilter.pipeline process:image];

  return filteredImage ?: image;
}

- (void)setCurrentFilter:(ARFilterDescriptor *)filter
           withIntensity:(float)intensity {
  self.currentFilter = filter;
  self.intensity = MAX(0.0f, MIN(1.0f, intensity)); // 确保强度在0-1范围内
}

- (void)setIntensity:(float)intensity {
  _intensity = MAX(0.0f, MIN(1.0f, intensity)); // 确保强度在0-1范围内
}

@end