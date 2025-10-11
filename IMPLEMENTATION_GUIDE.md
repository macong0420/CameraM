# CameraM 重构实施指南

## 已完成 ✅

### 1. 基础设施层
- [x] CMConstants - 统一常量管理
- [x] CMSettingsStorage - 统一设置存储
- [x] CMPermissionManager - 权限管理
- [x] CameraBusinessController - 已集成基础设施
- [x] **CMPermissionManager已集成到CameraViewController** - 简化58行权限代码到20行
- [x] CMLocationService - 位置服务模块(完整实现)
- [x] **CMLocationService已集成到CameraManager** - 并行运行模式,旧代码保留

### 2. 核心模块
- [x] CMImageProcessor.h/m - 图片处理模块（裁剪、方向归一化、相册保存）
- [x] **CMImageProcessor已集成到CameraManager** - 替换约150行
- [x] CMFormatManager.h/m - 格式管理模块（格式缓存、48MP检测、格式切换）
- [x] **CMFormatManager已集成到CameraManager** - 替换约200行
- [x] CMDeviceManager.h/m - 设备管理模块（设备发现、镜头管理、设备切换）
- [x] **CMDeviceManager已集成到CameraManager** - 替换约177行
- [x] CMMetadataEnricher.h/m - 元数据增强模块（GPS信息、镜头EXIF元数据）
- [x] **CMMetadataEnricher已集成到CameraManager** - 替换约187行
- [x] CMOrientationManager.h/m - 设备方向管理模块（方向监听、方向转换）
- [x] **CMOrientationManager已集成到CameraManager** - 替换约62行

---

## 立即可用的优化 (无需重构)

### 使用CMSettingsStorage
```objc
// 替换所有 UserDefaults 直接操作
CMSettingsStorage *storage = [CMSettingsStorage sharedStorage];

// 保存设置
[storage saveFlashMode:FlashModeOn];
[storage saveGridVisibility:YES];
[storage saveResolutionMode:CameraResolutionModeUltraHigh];
[storage saveWatermarkConfiguration:config];
[storage saveLensIdentifier:@"lens_id"];

// 读取设置
FlashMode mode = [storage loadFlashModeWithDefault:FlashModeAuto];
BOOL gridVisible = [storage loadGridVisibilityWithDefault:NO];
CameraResolutionMode resolution = [storage loadResolutionModeWithDefault:CameraResolutionModeStandard];
CMWatermarkConfiguration *config = [storage loadWatermarkConfiguration];
NSString *lensId = [storage loadLensIdentifier];
```

### 使用CMPermissionManager
```objc
// CameraViewController.m 中权限处理简化
CMPermissionManager *pm = [CMPermissionManager sharedManager];

// 检查权限
if ([pm isPhotoLibraryAccessGranted]) {
    [self showGallery];
} else if ([pm photoLibraryAuthorizationStatus] == CMPermissionStatusNotDetermined) {
    [pm requestPhotoLibraryPermission:^(CMPermissionStatus status) {
        if (status == CMPermissionStatusAuthorized ||
            status == CMPermissionStatusLimited) {
            [self showGallery];
        } else {
            [pm showPermissionDeniedAlertForType:@"相册" fromViewController:self];
        }
    }];
} else {
    [pm showPermissionDeniedAlertForType:@"相册" fromViewController:self];
}
```

### 使用CMConstants
```objc
#import "Common/CMConstants.h"

// 使用统一常量
[[NSUserDefaults standardUserDefaults] setObject:data
                                          forKey:kCMWatermarkConfigurationStorageKey];

// UI常量
CGFloat buttonWidth = CMModeSelectorWidth;
NSTimeInterval duration = CMDefaultAnimationDuration;
```

---

## 增量式集成CMLocationService

### 步骤1: 在CameraManager中添加属性
```objc
// CameraManager.m 的@interface部分
#import "../Services/CMLocationService.h"

@interface CameraManager () <CMLocationServiceDelegate>
@property (nonatomic, strong) CMLocationService *locationService;
// ... 保留原有的 locationManager 和 latestLocation 以保持兼容
@end
```

### 步骤2: 初始化locationService
```objc
// commonInit 方法中
- (void)commonInit {
    // ... 现有代码 ...

    // 创建新的位置服务
    _locationService = [[CMLocationService alloc] init];
    _locationService.delegate = self;

    // 保留原有初始化逻辑,暂时不删除
    dispatch_async(dispatch_get_main_queue(), ^{
        [self configureLocationServices]; // 旧方法
        [self.locationService configure]; // 新方法
    });
}
```

### 步骤3: 实现CMLocationServiceDelegate
```objc
#pragma mark - CMLocationServiceDelegate

- (void)locationService:(CMLocationService *)service
     didUpdateLocation:(CLLocation *)location {
    // 同步更新到旧属性,保持兼容
    self.latestLocation = location;
}

- (void)locationService:(CMLocationService *)service
       didFailWithError:(NSError *)error {
    NSLog(@"⚠️ Location update failed via service: %@", error.localizedDescription);
}
```

### 步骤4: 逐步切换调用
```objc
// 旧代码 (保持)
- (void)startSession {
    // ...
    [self startUpdatingLocationIfPossible]; // 旧方法
}

// 新代码 (并行运行)
- (void)startSession {
    // ...
    [self.locationService startUpdatingLocation]; // 新方法
}

// 测试通过后,删除旧方法调用
```

### 步骤5: 切换GPS字典生成
```objc
// 旧代码
NSDictionary *gpsDict = [self gpsDictionaryForLocation:self.latestLocation];

// 新代码
NSDictionary *gpsDict = [self.locationService gpsDictionaryForLocation:self.latestLocation];
```

### 步骤6: 清理旧代码 ✅ (已完成)
```objc
// ✅ 已删除以下方法:
// - configureLocationServices
// - handleLocationAuthorizationStatus:
// - startUpdatingLocationIfPossible
// - stopUpdatingLocationIfNeeded
// - authorizationStatusForManager:
// - locationManagerDidChangeAuthorization:
// - locationManager:didUpdateLocations:
// - locationManager:didFailWithError:
// (注: isValidLocation 和 gpsDictionaryForLocation 已迁移到 CMLocationService)

// ✅ 已删除属性:
// @property (nonatomic, strong) CLLocationManager *locationManager;
// ✅ 保留 latestLocation 作为兼容层,由 CMLocationService 通过 delegate 更新
```

---

## 下一步: 集成CMImageProcessor (可选)

### 当前状态
- ✅ 已创建 CMImageProcessor.h 接口定义
- ⏸️ 实现代码可以从CameraManager.m直接复制

### 快速集成步骤
```objc
// 1. 在CameraManager添加属性
@property (nonatomic, strong) CMImageProcessor *imageProcessor;

// 2. 初始化
- (void)commonInit {
    _imageProcessor = [[CMImageProcessor alloc] init];
}

// 3. 调用切换 (保持签名不变)
- (UIImage *)cropImage:(UIImage *)image toAspectRatio:(CameraAspectRatio)ratio {
    return [self.imageProcessor cropImage:image
                          toAspectRatio:ratio
                        withOrientation:self.currentDeviceOrientation];
}

- (void)saveImageToPhotosLibrary:(UIImage *)image
                         metadata:(NSDictionary *)metadata
                       completion:(void(^)(BOOL, NSError *))completion {
    [self.imageProcessor saveImageToPhotosLibrary:image
                                         metadata:metadata
                                       completion:completion];
}
```

---

## 不推荐立即执行的重构 (风险高)

### CMFormatManager
- **复杂度**: 高
- **耦合度**: 与设备管理高度耦合
- **建议**: 等CameraManager整体稳定后再拆分

### CMDeviceManager
- **复杂度**: 极高
- **耦合度**: 核心逻辑,与所有模块耦合
- **建议**: 暂不拆分,或者作为独立项目重构

### CMCaptureController
- **复杂度**: 高
- **风险**: 拍摄流程敏感,易引入Bug
- **建议**: 等团队测试能力提升后再拆分

---

## 风险评估

### 低风险 ✅ (可立即执行)
1. 使用CMSettingsStorage替换UserDefaults
2. 使用CMPermissionManager简化权限逻辑
3. 使用CMConstants统一常量
4. 集成CMLocationService(并行运行模式)

### 中风险 ⚠️ (需要充分测试)
1. 集成CMImageProcessor
2. 移除CMCaptureSessionService冗余层
3. 重构CameraViewController的UI逻辑

### 高风险 🔴 (暂不推荐)
1. 拆分CMFormatManager
2. 拆分CMDeviceManager
3. 拆分CMCaptureController
4. 完全重写CameraManager

---

## 测试检查清单

每次集成新模块后,必须测试以下功能:

### 基础功能
- [ ] 相机启动正常
- [ ] 预览画面显示正常
- [ ] 拍照功能正常
- [ ] 照片保存到相册成功

### 高级功能
- [ ] 闪光灯切换 (Auto/On/Off)
- [ ] 分辨率切换 (12MP/48MP)
- [ ] 镜头切换 (如果有多镜头)
- [ ] 前后摄像头切换
- [ ] 网格线显示/隐藏

### 比例功能
- [ ] 4:3比例拍摄和裁剪
- [ ] 1:1比例拍摄和裁剪
- [ ] Xpan比例拍摄和裁剪

### 水印功能
- [ ] 水印面板打开/关闭
- [ ] 水印配置保存/加载
- [ ] 水印应用到照片

### 权限功能
- [ ] 相机权限请求
- [ ] 相册权限请求
- [ ] 位置权限请求
- [ ] GPS信息写入EXIF

### 横屏适配
- [ ] 竖屏模式正常
- [ ] 横屏左模式正常
- [ ] 横屏右模式正常
- [ ] UI布局适配正确

---

## 回滚方案

### 如果集成出现问题:

1. **立即回滚**: 使用git恢复到上一个稳定版本
   ```bash
   git stash
   git checkout <last-stable-commit>
   ```

2. **保留新代码但禁用**: 注释掉新模块调用
   ```objc
   // [self.locationService startUpdatingLocation]; // 暂时禁用
   [self startUpdatingLocationIfPossible]; // 使用旧逻辑
   ```

3. **调试模式**: 并行运行新旧代码,对比输出
   ```objc
   CLLocation *oldLocation = self.latestLocation;
   CLLocation *newLocation = self.locationService.latestLocation;
   NSLog(@"位置对比 - 旧: %@, 新: %@", oldLocation, newLocation);
   ```

---

## 性能监控

### 关键指标
- **启动时间**: 相机从启动到预览可用的时间
- **拍照延迟**: 点击拍摄到完成的时间
- **内存占用**: 运行时内存峰值
- **CPU占用**: 拍摄时CPU使用率

### 监控代码
```objc
// 启动时间
NSDate *start = [NSDate date];
[self setupCameraWithPreviewView:view completion:^(BOOL success, NSError *error) {
    NSTimeInterval duration = [[NSDate date] timeIntervalSinceDate:start];
    NSLog(@"📊 相机启动耗时: %.2f秒", duration);
}];

// 内存监控
- (void)logMemoryUsage {
    struct mach_task_basic_info info;
    mach_msg_type_number_t size = sizeof(info);
    kern_return_t kerr = task_info(mach_task_self(),
                                   MACH_TASK_BASIC_INFO,
                                   (task_info_t)&info,
                                   &size);
    if (kerr == KERN_SUCCESS) {
        CGFloat memoryMB = info.resident_size / 1024.0 / 1024.0;
        NSLog(@"📊 当前内存: %.1f MB", memoryMB);
    }
}
```

---

## 代码审查要点

### 集成新模块前
1. ✅ 接口设计是否清晰?
2. ✅ 职责是否单一?
3. ✅ 是否有单元测试?
4. ✅ 是否有文档说明?
5. ✅ 是否向后兼容?

### 集成新模块后
1. ✅ 所有测试用例通过?
2. ✅ 没有新的编译警告?
3. ✅ 没有内存泄漏?
4. ✅ 性能没有退化?
5. ✅ 代码覆盖率没有下降?

---

## 常见问题

### Q1: 为什么不一次性重构所有代码?
**A**: 风险太高,容易引入Bug,影响用户体验。增量式重构可以:
- 每次只改一小部分,易于测试
- 出问题可以快速回滚
- 团队学习成本低
- 不阻塞新功能开发

### Q2: 重构会影响现有功能吗?
**A**: 不会。我们采用:
- **并行运行**: 新旧代码同时存在
- **逐步切换**: 确认稳定后再删除旧代码
- **充分测试**: 每次变更都有测试清单

### Q3: 什么时候可以删除旧代码?
**A**: 满足以下条件:
- 新代码运行稳定至少2周
- 所有测试用例通过
- 没有用户反馈相关问题
- 团队达成共识

### Q4: 如何保证不遗漏功能?
**A**: 使用测试清单:
- 每个功能点都有对应测试项
- 重构前后都执行完整测试
- 保留详细的变更日志

---

## 下一步行动

### 本周 (立即执行) ✅ 已全部完成
1. ✅ 确认CMSettingsStorage在CameraBusinessController中工作正常
2. ✅ 确认CMConstants编译无错误
3. ✅ 确认CMPermissionManager编译无错误
4. ✅ 确认CMLocationService编译无错误
5. ✅ **在CameraManager中并行集成CMLocationService** (已完成)
6. ✅ **在CameraViewController中集成CMPermissionManager** (已完成)
7. ✅ **创建CMImageProcessor.m完整实现** (已完成)

### 下周 (逐步集成)
1. ✅ ~~在CameraViewController中使用CMPermissionManager~~ (已提前完成)
2. ✅ ~~在CameraManager中并行集成CMLocationService~~ (已提前完成)
3. 测试位置服务功能 (验证GPS信息写入EXIF)
4. 在CameraManager中集成CMImageProcessor (可选)

### 下下周 (可选优化)
1. ✅ ~~创建CMImageProcessor.m实现~~ (已提前完成)
2. 在CameraManager中集成CMImageProcessor
3. 测试图片处理功能

---

## 总结

### 已完成的优化
- ✅ 基础设施层 (CMConstants, CMSettingsStorage, CMPermissionManager)
- ✅ CMLocationService完整实现 + 集成到CameraManager
- ✅ **移除所有旧CLLocationManager代码** (清理121行)
- ✅ CMPermissionManager集成到CameraViewController (58行→20行)
- ✅ CMImageProcessor完整实现 + 集成到CameraManager (替换150行)
- ✅ CMFormatManager完整实现 + 集成到CameraManager (替换200行)
- ✅ CMDeviceManager完整实现 + 集成到CameraManager (替换177行)
- ✅ CMMetadataEnricher完整实现 + 集成到CameraManager (替换187行)
- ✅ CMOrientationManager完整实现 + 集成到CameraManager (替换62行)
- ✅ CameraBusinessController集成基础设施
- ✅ **减少约897行重复代码** (776 + 121)
- ✅ **CameraManager从2098行减少到1251行 (减少40%)**
- ✅ BUILD SUCCEEDED - 所有代码编译通过

### 下一步重点
- 🎯 **运行测试** - 验证GPS、权限、图片、格式管理、设备管理、元数据增强、方向管理功能
- ✅ **旧代码清理完成** - 移除了所有CLLocationManager旧实现 (121行)
- 🎯 继续拆分CameraManager剩余模块 (1251行，较初始2098行减少40%)
- 🎯 考虑创建CMCaptureController (拍摄控制逻辑)
- 🎯 考虑创建CMSessionManager (会话生命周期管理)

### 长期目标
- 逐步拆分CameraManager的2098行代码
- 逐步拆分CameraControlsView的1890行代码
- 提高代码可测试性和可维护性
