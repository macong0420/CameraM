# CameraM 架构重构计划

## 已完成优化 ✅

### 1. 基础设施层 (已完成)

#### a) CMConstants (统一常量管理)
**位置**: `/CameraM/Common/CMConstants.h/m`

**功能**:
- 集中管理UserDefaults键名
- 统一Error Domain定义
- UI常量定义

**使用示例**:
```objc
#import "Common/CMConstants.h"

// 使用统一常量
[[NSUserDefaults standardUserDefaults] setObject:data
                                          forKey:kCMWatermarkConfigurationStorageKey];
```

#### b) CMSettingsStorage (统一设置存储)
**位置**: `/CameraM/Common/CMSettingsStorage.h/m`

**功能**:
- 封装所有UserDefaults操作
- 提供类型安全的存储接口
- 简化持久化逻辑

**使用示例**:
```objc
// 保存设置
[[CMSettingsStorage sharedStorage] saveFlashMode:FlashModeOn];

// 读取设置
FlashMode mode = [[CMSettingsStorage sharedStorage]
                   loadFlashModeWithDefault:FlashModeAuto];
```

#### c) CMPermissionManager (权限管理)
**位置**: `/CameraM/Common/CMPermissionManager.h/m`

**功能**:
- 统一相机/相册权限检查
- 简化权限请求流程
- 提供通用权限拒绝弹窗

**使用示例**:
```objc
CMPermissionManager *pm = [CMPermissionManager sharedManager];

// 检查权限
if ([pm isPhotoLibraryAccessGranted]) {
    // 执行操作
} else {
    // 请求权限
    [pm requestPhotoLibraryPermission:^(CMPermissionStatus status) {
        // 处理结果
    }];
}
```

### 2. CameraBusinessController 重构 (已完成)

**变更**:
- ✅ 移除重复的常量定义
- ✅ 使用 `CMSettingsStorage` 替代所有 UserDefaults 操作
- ✅ 持久化方法从50+行简化为1行调用

**优化效果**:
- 代码行数减少约60行
- 消除了5处重复的持久化逻辑
- 提高可测试性

---

## 待重构架构设计 (高优先级)

### 3. CameraManager 拆分 (P0)

**当前问题**: 2098行上帝类,承担9种职责

#### 目标架构:
```
CameraManager (协调者 ~300行)
  ├── CMDeviceManager (设备管理 ~400行)
  │     - 设备发现与切换
  │     - 输入输出配置
  │     - 镜头选项管理
  │
  ├── CMCaptureController (拍摄控制 ~300行)
  │     - 照片拍摄
  │     - 对焦/曝光
  │     - 闪光灯控制
  │
  ├── CMFormatManager (格式管理 ~400行)
  │     - 设备格式缓存
  │     - 分辨率切换
  │     - 4800万像素支持检测
  │
  ├── CMLocationService (位置服务 ~250行)
  │     - GPS定位
  │     - 位置权限管理
  │     - EXIF位置写入
  │
  └── CMImageProcessor (图片处理 ~350行)
        - 图片裁剪
        - 方向归一化
        - 相册保存
```

#### 拆分步骤:

##### 步骤1: 创建 CMLocationService (独立性最高)
```objc
// /CameraM/Services/CMLocationService.h
@protocol CMLocationServiceDelegate <NSObject>
- (void)locationService:(CMLocationService *)service
     didUpdateLocation:(CLLocation *)location;
@end

@interface CMLocationService : NSObject
@property (nonatomic, weak) id<CMLocationServiceDelegate> delegate;
- (void)startUpdating;
- (void)stopUpdating;
- (CLLocation *)latestLocation;
@end
```

**迁移代码** (从CameraManager.m):
- 位置248-354行 (位置服务相关方法)
- CLLocationManager 相关属性

##### 步骤2: 创建 CMImageProcessor
```objc
// /CameraM/Services/CMImageProcessor.h
@interface CMImageProcessor : NSObject
- (UIImage *)normalizeOrientation:(UIImage *)image;
- (UIImage *)cropImage:(UIImage *)image toAspectRatio:(CameraAspectRatio)ratio;
- (CGRect)cropRectForAspectRatio:(CameraAspectRatio)ratio
                     inImageSize:(CGSize)imageSize;
- (void)saveImageToPhotosLibrary:(UIImage *)image
                         metadata:(NSDictionary *)metadata
                       completion:(void(^)(BOOL, NSError *))completion;
@end
```

**迁移代码**:
- 图片处理相关方法 (cropImage:, cropRectForAspectRatio:等)
- PHPhotoLibrary保存逻辑

##### 步骤3: 创建 CMFormatManager
```objc
// /CameraM/Managers/CMFormatManager.h
@interface CMFormatManager : NSObject
- (void)cacheFormatsForDevice:(AVCaptureDevice *)device;
- (AVCaptureDeviceFormat *)standardFormatForDevice:(AVCaptureDevice *)device;
- (AVCaptureDeviceFormat *)ultraHighFormatForDevice:(AVCaptureDevice *)device;
- (BOOL)deviceSupportsUltraHigh:(AVCaptureDevice *)device;
@end
```

**迁移代码**:
- Format缓存字典 (standardDeviceFormats, ultraHighDeviceFormats)
- 格式查找/切换相关方法

##### 步骤4: 创建 CMDeviceManager
```objc
// /CameraM/Managers/CMDeviceManager.h
@interface CMDeviceManager : NSObject
- (NSArray<AVCaptureDevice *> *)availableDevicesForPosition:(CameraPosition)pos;
- (AVCaptureDevice *)selectDefaultDevice;
- (void)switchToDevice:(AVCaptureDevice *)device
             inSession:(AVCaptureSession *)session;
- (NSArray<CMCameraLensOption *> *)lensOptionsForDevices:(NSArray *)devices;
@end
```

**迁移代码**:
- 设备发现逻辑 (discoverDevicesForPosition:)
- 镜头选项构建 (rebuildLensOptionsForPosition:)
- 设备切换 (switchCamera方法核心)

##### 步骤5: 创建 CMCaptureController
```objc
// /CameraM/Managers/CMCaptureController.h
@protocol CMCaptureControllerDelegate <NSObject>
- (void)captureController:(CMCaptureController *)controller
         didCapturePhoto:(UIImage *)image
            withMetadata:(NSDictionary *)metadata;
@end

@interface CMCaptureController : NSObject <AVCapturePhotoCaptureDelegate>
- (void)capturePhotoWithSession:(AVCaptureSession *)session
                    photoOutput:(AVCapturePhotoOutput *)output;
- (void)focusAtPoint:(CGPoint)point onDevice:(AVCaptureDevice *)device;
- (void)setExposure:(float)value onDevice:(AVCaptureDevice *)device;
@end
```

**迁移代码**:
- capturePhoto方法
- AVCapturePhotoCaptureDelegate 实现
- 对焦/曝光控制方法

##### 步骤6: 重构 CameraManager 为协调者
```objc
@interface CameraManager : NSObject
@property (nonatomic, strong) CMDeviceManager *deviceManager;
@property (nonatomic, strong) CMCaptureController *captureController;
@property (nonatomic, strong) CMFormatManager *formatManager;
@property (nonatomic, strong) CMLocationService *locationService;
@property (nonatomic, strong) CMImageProcessor *imageProcessor;

// 协调方法
- (void)setupCameraWithPreviewView:(UIView *)view
                        completion:(void(^)(BOOL, NSError *))completion;
- (void)capturePhoto;
- (void)switchCamera;
// ...
@end

@implementation CameraManager
- (void)capturePhoto {
    // 协调各模块
    [self.captureController capturePhotoWithSession:self.captureSession
                                        photoOutput:self.photoOutput];
}
@end
```

---

### 4. CameraControlsView 拆分 (P0)

**当前问题**: 1890行上帝类,28个属性,职责过于庞大

#### 目标架构:
```
CameraControlsView (容器 ~200行)
  ├── CMTopToolbar (顶部工具栏 ~300行)
  │     - 闪光灯/网格/切换相机按钮
  │     - 比例选择器
  │     - 水印/设置按钮
  │
  ├── CMBottomControls (底部控制 ~400行)
  │     - 拍摄按钮 (loading状态)
  │     - 相册按钮
  │     - 模式选择器
  │
  ├── CMExposureControl (曝光控制 ~150行)
  │     - 垂直滑块
  │     - 曝光指示
  │
  ├── CMLensSelector (镜头选择 ~250行)
  │     - 镜头选项列表
  │     - 选中状态
  │
  ├── CMFocusIndicator (对焦指示 ~150行)
  │     - 对焦方框动画
  │     - 网格线显示
  │
  └── CMStatusIndicators (状态指示 ~180行)
        - 分辨率标签
        - 闪光模式标签
        - 水印状态指示
```

#### 拆分步骤:

##### 步骤1: 创建 CMTopToolbar
```objc
// /CameraM/Views/Controls/CMTopToolbar.h
@protocol CMTopToolbarDelegate <NSObject>
- (void)topToolbarDidTapFlash:(CMTopToolbar *)toolbar;
- (void)topToolbarDidTapGrid:(CMTopToolbar *)toolbar;
- (void)topToolbarDidTapAspectRatio:(CMTopToolbar *)toolbar;
- (void)topToolbarDidTapSwitchCamera:(CMTopToolbar *)toolbar;
- (void)topToolbarDidTapWatermark:(CMTopToolbar *)toolbar;
- (void)topToolbarDidTapSettings:(CMTopToolbar *)toolbar;
@end

@interface CMTopToolbar : UIView
@property (nonatomic, weak) id<CMTopToolbarDelegate> delegate;
- (void)updateFlashModeText:(NSString *)text highlighted:(BOOL)highlighted;
- (void)updateAspectRatioText:(NSString *)text;
- (void)updateLayout:(CameraDeviceOrientation)orientation;
@end
```

**迁移代码** (从CameraControlsView.m):
- setupTopControls方法 (160-205行)
- 顶部按钮相关属性和方法

##### 步骤2: 创建 CMBottomControls
```objc
// /CameraM/Views/Controls/CMBottomControls.h
@protocol CMBottomControlsDelegate <NSObject>
- (void)bottomControlsDidTapCapture:(CMBottomControls *)controls;
- (void)bottomControlsDidTapGallery:(CMBottomControls *)controls;
- (void)bottomControls:(CMBottomControls *)controls didSelectMode:(NSInteger)mode;
@end

@interface CMBottomControls : UIView
- (void)updateGalleryButtonWithImage:(UIImage *)image;
- (void)setCaptureButtonLoading:(BOOL)loading;
- (void)setCaptureButtonEnabled:(BOOL)enabled;
- (void)updateLayout:(CameraDeviceOrientation)orientation;
@end
```

**迁移代码**:
- setupBottomControls方法 (207-253行)
- 拍摄按钮/相册按钮逻辑

##### 步骤3: 创建其他组件
按照类似模式创建:
- CMExposureControl (专业控制)
- CMLensSelector (镜头选择)
- CMFocusIndicator (对焦/网格)
- CMStatusIndicators (状态标签)

##### 步骤4: 重构 CameraControlsView 为容器
```objc
@interface CameraControlsView : UIView
@property (nonatomic, strong) CMTopToolbar *topToolbar;
@property (nonatomic, strong) CMBottomControls *bottomControls;
@property (nonatomic, strong) CMExposureControl *exposureControl;
@property (nonatomic, strong) CMLensSelector *lensSelector;
@property (nonatomic, strong) CMFocusIndicator *focusIndicator;
@property (nonatomic, strong) CMStatusIndicators *statusIndicators;

- (void)setupUI;
- (void)updateLayoutForOrientation:(CameraDeviceOrientation)orientation;
@end

@implementation CameraControlsView
- (void)setupUI {
    // 创建并布局各子组件
    self.topToolbar = [[CMTopToolbar alloc] init];
    self.topToolbar.delegate = self;
    [self addSubview:self.topToolbar];

    // ... 其他组件
}

// 转发delegate调用
- (void)topToolbarDidTapFlash:(CMTopToolbar *)toolbar {
    if ([self.delegate respondsToSelector:@selector(didTapFlashButton)]) {
        [self.delegate didTapFlashButton];
    }
}
@end
```

---

### 5. 移除 CMCaptureSessionService 冗余层 (P1)

**问题**: 167行纯转发代理,无实际价值

**解决方案**:

#### 方案A: 完全移除 (推荐)
```objc
// CameraBusinessController.h
- (instancetype)initWithCameraManager:(CameraManager *)manager;

// CameraBusinessController.m
- (instancetype)initWithCameraManager:(CameraManager *)manager {
    self = [super init];
    if (self) {
        _cameraManager = manager ?: [CameraManager sharedManager];
        _cameraManager.delegate = self;
        // ...
    }
    return self;
}
```

#### 方案B: 赋予真正职责
如果保留,应该实现真正的抽象:
```objc
// 策略模式 - 支持不同相机实现
@protocol CMCaptureSessionServicing <NSObject>
// 保持接口不变
@end

// 真实实现
@interface CMRealCaptureService : NSObject <CMCaptureSessionServicing>
@end

// Mock实现 (用于测试)
@interface CMMockCaptureService : NSObject <CMCaptureSessionServicing>
@end
```

---

### 6. CameraViewController 职责重构 (P1)

**当前问题**:
- UI构建逻辑应该在View层
- 权限处理应该用 CMPermissionManager
- 业务逻辑侵入

#### 优化点:

##### a) 使用 CMPermissionManager
```objc
// 重构前 (429-485行,58行代码)
- (void)presentCustomGallery {
    PHAuthorizationStatus status;
    if (@available(iOS 14, *)) {
        status = [PHPhotoLibrary authorizationStatusForAccessLevel:...];
    } else {
        status = [PHPhotoLibrary authorizationStatus];
    }
    // ... 复杂的权限检查和回调嵌套
}

// 重构后 (10行代码)
- (void)presentCustomGallery {
    CMPermissionManager *pm = [CMPermissionManager sharedManager];

    if ([pm isPhotoLibraryAccessGranted]) {
        [self showGalleryController];
        return;
    }

    CMPermissionStatus status = [pm photoLibraryAuthorizationStatus];
    if (status == CMPermissionStatusNotDetermined) {
        [pm requestPhotoLibraryPermission:^(CMPermissionStatus status) {
            if (status == CMPermissionStatusAuthorized ||
                status == CMPermissionStatusLimited) {
                [self showGalleryController];
            } else {
                [pm showPermissionDeniedAlertForType:@"相册"
                                  fromViewController:self];
            }
        }];
    } else {
        [pm showPermissionDeniedAlertForType:@"相册"
                          fromViewController:self];
    }
}
```

##### b) 移动UI构建到View层
```objc
// 重构前: CameraViewController.m:613-629 (UI构建逻辑)
- (UIButton *)importActionButtonWithTitle:(NSString *)title primary:(BOOL)isPrimary {
    // 28行按钮创建代码
}

// 重构后: 创建 UIButton+CMStyle 或 CMButtonFactory
// /CameraM/Views/Extensions/UIButton+CMStyle.h
@interface UIButton (CMStyle)
+ (UIButton *)cm_importActionButtonWithTitle:(NSString *)title
                                      primary:(BOOL)isPrimary
                                       target:(id)target
                                       action:(SEL)action;
@end

// CameraViewController.m 使用
UIButton *cancelButton = [UIButton cm_importActionButtonWithTitle:@"取消"
                                                          primary:NO
                                                           target:self
                                                           action:@selector(handleImportCancelTap)];
```

---

## 渐进式迁移策略

### 阶段1: 立即应用基础设施 ✅ (已完成)
- [x] 使用 CMConstants
- [x] 使用 CMSettingsStorage
- [x] 集成 CMPermissionManager

### 阶段2: 拆分CameraManager (2-3周)
优先级顺序:
1. CMLocationService (最独立)
2. CMImageProcessor
3. CMFormatManager
4. CMDeviceManager
5. CMCaptureController
6. 重构CameraManager为协调者

### 阶段3: 拆分CameraControlsView (2-3周)
优先级顺序:
1. CMFocusIndicator (最独立)
2. CMExposureControl
3. CMStatusIndicators
4. CMLensSelector
5. CMTopToolbar
6. CMBottomControls
7. 重构CameraControlsView为容器

### 阶段4: 清理架构 (1周)
1. 移除CMCaptureSessionService
2. 重构CameraViewController
3. 补充单元测试

---

## 预期效果

### 代码指标:
| 类 | 重构前 | 重构后 | 减少 |
|---|--------|--------|------|
| CameraManager | 2098行 | ~300行 | 85% |
| CameraControlsView | 1890行 | ~200行 | 89% |
| CameraViewController | 999行 | ~600行 | 40% |
| CameraBusinessController | 597行 | ~400行 | 33% |

### 架构指标:
- ✅ 消除2个上帝类
- ✅ 单一职责原则遵守率: 30% → 90%
- ✅ 平均类复杂度降低: 70%
- ✅ 可测试性提升: 80%
- ✅ 新功能开发效率提升: 50%

---

## 风险与注意事项

### 风险:
1. **回归Bug风险**: 拆分过程中可能引入Bug
   - **缓解**: 每次拆分后充分测试
   - **缓解**: 保持小步快跑,逐个模块迁移

2. **合并冲突**: 多人开发时冲突增加
   - **缓解**: 使用feature branch隔离重构
   - **缓解**: 优先迁移改动少的模块

3. **学习成本**: 新架构需要团队学习
   - **缓解**: 提供详细文档和示例代码

### 注意事项:
- ⚠️ **不要一次性重构**: 使用渐进式迁移
- ⚠️ **保持向后兼容**: 旧代码路径逐步废弃
- ⚠️ **测试覆盖**: 每次拆分后补充单元测试
- ⚠️ **代码审查**: 重构PR必须严格Review

---

## 下一步行动

1. ✅ **已完成**: 基础设施集成
2. **本周**: 创建并迁移 CMLocationService
3. **下周**: 创建并迁移 CMImageProcessor
4. **后续**: 按计划逐步拆分其他模块

---

## 参考资料

### 设计原则:
- SOLID原则
- 单一职责原则 (SRP)
- 依赖倒置原则 (DIP)
- 接口隔离原则 (ISP)

### 设计模式:
- 协调者模式 (Coordinator)
- 策略模式 (Strategy)
- 工厂模式 (Factory)
- 委托模式 (Delegate)

### 重构技巧:
- 《重构:改善既有代码的设计》- Martin Fowler
- Extract Class (提取类)
- Move Method (搬移方法)
- Replace Inheritance with Delegation (以委托取代继承)
