#import <UIKit/UIKit.h>

static NSMutableArray* tapTasks;
static BOOL isAutoTapOn = NO;
static dispatch_source_t tapTimer;

@interface FloatWindow : UIWindow
@property (nonatomic, strong) UIButton *floatBtn;
@end

@interface CoordinatePickerWindow : UIWindow
@property (nonatomic, strong) UIView *dragPointer;
@property (nonatomic, strong) UIButton *confirmBtn;
@property (nonatomic, copy) void(^onGetPoint)(CGPoint pt);
@end

@implementation CoordinatePickerWindow
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if(self){
        self.windowLevel = UIWindowLevelAlert + 10;
        self.backgroundColor = [UIColor clearColor];
        self.dragPointer = [[UIView alloc] initWithFrame:CGRectMake(200,200,40,40)];
        self.dragPointer.backgroundColor = [UIColor colorWithRed:1 green:0.2 blue:0.2 alpha:0.7];
        self.dragPointer.layer.cornerRadius = 20;
        [self addSubview:self.dragPointer];
        
        UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(onDrag:)];
        [self.dragPointer addGestureRecognizer:pan];
        
        self.confirmBtn = [UIButton buttonWithType:UIButtonTypeSystem];
        self.confirmBtn.frame = CGRectMake(20, self.bounds.size.height - 80, 160,44);
        [self.confirmBtn setTitle:@"✅确认获取坐标" forState:UIControlStateNormal];
        [self.confirmBtn addTarget:self action:@selector(onConfirm) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:self.confirmBtn];
    }
    return self;
}
- (void)onDrag:(UIPanGestureRecognizer*)g {
    CGPoint trans = [g translationInView:self];
    CGPoint c = self.dragPointer.center;
    self.dragPointer.center = CGPointMake(c.x + trans.x, c.y + trans.y);
    [g setTranslation:CGPointZero inView:self];
}
- (void)onConfirm {
    if(self.onGetPoint){
        self.onGetPoint(self.dragPointer.center);
    }
    self.hidden = YES;
}
@end

@implementation FloatWindow
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if(self){
        tapTasks = [NSMutableArray array];
        self.windowLevel = UIWindowLevelAlert + 5;
        self.backgroundColor = [UIColor clearColor];
        
        self.floatBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        self.floatBtn.frame = CGRectMake(20,20,50,50);
        self.floatBtn.backgroundColor = [UIColor systemBlueColor];
        self.floatBtn.layer.cornerRadius = 25;
        [self.floatBtn setTitle:@"⚡" forState:UIControlStateNormal];
        self.floatBtn.titleLabel.font = [UIFont boldSystemFontOfSize:22];
        [self addSubview:self.floatBtn];
        
        [self.floatBtn addTarget:self action:@selector(toggleAutoTap) forControlEvents:UIControlEventTouchUpInside];
        UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(longTapMenu:) minimumPressDuration:0.4];
        [self.floatBtn addGestureRecognizer:longPress];
    }
    return self;
}

- (void)longTapMenu:(UILongPressGestureRecognizer *)gesture {
    if(gesture.state == UIGestureRecognizerStateBegan){
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"自动点击菜单" message:@"添加点位，自定义CPS(10~100)" preferredStyle:UIAlertControllerStyleActionSheet];
        
        [alert addAction:[UIAlertAction actionWithTitle:@"➕ 添加点击点位" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            CoordinatePickerWindow *picker = [[CoordinatePickerWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
            picker.hidden = NO;
            picker.onGetPoint = ^(CGPoint pt) {
                UIAlertController *cpsInput = [UIAlertController alertControllerWithTitle:@"设置CPS" message:@"输入10~100之间数字" preferredStyle:UIAlertControllerStyleAlert];
                [cpsInput addTextFieldWithConfigurationHandler:^(UITextField *tf) {
                    tf.keyboardType = UIKeyboardTypeDecimalPad;
                    tf.placeholder = @"例如：20";
                }];
                [cpsInput addAction:[UIAlertAction actionWithTitle:@"保存" style:UIAlertActionStyleDefault handler:^(UIAlertAction *act) {
                    double cps = [cpsInput.textFields.firstObject.text doubleValue];
                    if(cps <10) cps=10;
                    if(cps>100) cps=100;
                    [tapTasks addObject:@{@"x":@(pt.x), @"y":@(pt.y), @"cps":@(cps)}];
                }]];
                [cpsInput addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
                UIViewController *rootVC = [[UIApplication sharedApplication].keyWindow rootViewController];
                [rootVC presentViewController:cpsInput animated:YES completion:nil];
            };
        }]];
        
        [alert addAction:[UIAlertAction actionWithTitle:@"➖ 删除最后点位" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
            if(tapTasks.count>0)[tapTasks removeLastObject];
        }]];
        [alert addAction:[UIAlertAction actionWithTitle:@"返回" style:UIAlertActionStyleCancel handler:nil]];
        UIViewController *rootVC = [[UIApplication sharedApplication].keyWindow rootViewController];
        [rootVC presentViewController:alert animated:YES completion:nil];
    }
}

- (void)toggleAutoTap {
    isAutoTapOn = !isAutoTapOn;
    if(isAutoTapOn){
        [self startTapLoop];
        self.floatBtn.backgroundColor = [UIColor systemRedColor];
    }else{
        [self stopTapLoop];
        self.floatBtn.backgroundColor = [UIColor systemBlueColor];
    }
}

- (void)startTapLoop {
    if(tapTimer) return;
    NSDictionary *task = tapTasks.firstObject;
    double cps = task ? [task[@"cps"] doubleValue] : 20;
    double interval = 1.0 / cps;
    
    tapTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER,0,0,dispatch_get_global_queue(0,0));
    dispatch_source_set_timer(tapTimer, DISPATCH_TIME_NOW, interval*NSEC_PER_SEC, 0);
    dispatch_source_set_event_handler(tapTimer,^{
        dispatch_async(dispatch_get_main_queue(),^{
            for(NSDictionary *t in tapTasks){
                CGPoint p = CGPointMake([t[@"x"] doubleValue], [t[@"y"] doubleValue]);
                [self simulateTap:p];
            }
        });
    });
    dispatch_resume(tapTimer);
}

- (void)stopTapLoop {
    if(tapTimer){
        dispatch_source_cancel(tapTimer);
        tapTimer = nil;
    }
}

- (void)simulateTap:(CGPoint)point {
    UIWindow *keyWindow = [[UIApplication sharedApplication].keyWindow];
    UITouch *touch = [[UITouch alloc] initWithWindow:keyWindow location:point];
    UIEvent *event = [UIEvent eventWithTouch:touch];
    [keyWindow sendEvent:event];
}
@end

__attribute__((constructor))
void entry(){
    dispatch_async(dispatch_get_main_queue(),^{
        FloatWindow *win = [[FloatWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
        win.hidden = NO;
    });
}
