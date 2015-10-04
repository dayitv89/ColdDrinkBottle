//
//  ViewController.m
//  LiquidFlow
//
//  Created by gauravds on 10/4/15.
//  Copyright © 2015 GDS. All rights reserved.
//

#import "ViewController.h"
#import "BAFluidView.h"
#import "DPMeterView.h"
#import "UIBezierPath+BasicShapes.h"

#import <QuartzCore/QuartzCore.h>
#import <CoreMotion/CoreMotion.h>

@interface ViewController ()
@property (nonatomic, strong) CMMotionManager* motionManager;
@property (nonatomic, strong) CADisplayLink* motionDisplayLink;
@property (nonatomic) float motionLastYaw;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];

//    [self.shapeView setHidden:YES];
    [self DPMeterView];
    
//    [self BAFluidView];
}

- (void)BAFluidView {
    //    BAFluidView *view = [[BAFluidView alloc] initWithFrame:self.view.frame];
    //    [view fillTo:@1.0];
    //    view.fillColor = UIColorFromRGB(0x397ebe);
    //    [view startAnimation];
    //    [view keepStationary];
    //    [self.view addSubview:view];
    
    
    
    BAFluidView *fluidView = [[BAFluidView alloc] initWithFrame:self.view.frame startElevation:@0.3];
    fluidView.fillColor = UIColorFromRGB(0x397ebe);
    [fluidView fillTo:@0.9];
    [fluidView setFillAutoReverse:NO];
    [fluidView setFillRepeatCount:1];
//    [fluidView startAnimation];
    [self.view addSubview:fluidView];
    
    UIImage *maskingImage = [UIImage imageNamed:@"icon"];
    CALayer *maskingLayer = [CALayer layer];
    maskingLayer.frame = CGRectMake(CGRectGetMidX(fluidView.frame) - maskingImage.size.width/2, 70, maskingImage.size.width, maskingImage.size.height);
    [maskingLayer setContents:(id)[maskingImage CGImage]];
    [fluidView.layer setMask:maskingLayer];
}


#pragma mark - Gravity Motion
- (void)startGravity
{
    self.motionManager = [[CMMotionManager alloc] init];
    self.motionManager.deviceMotionUpdateInterval = 0.02; // 50 Hz
    
    self.motionLastYaw = 0;
    self.motionDisplayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(motionRefresh:)];
    [self.motionDisplayLink addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    if ([self.motionManager isDeviceMotionAvailable]) {
        // to avoid using more CPU than necessary we use ``CMAttitudeReferenceFrameXArbitraryZVertical``
        [self.motionManager startDeviceMotionUpdatesUsingReferenceFrame:CMAttitudeReferenceFrameXArbitraryZVertical];
    }
}

- (void)stopGravity {
    if ([self.motionManager isDeviceMotionActive])
        [self.motionManager stopDeviceMotionUpdates];
}

- (void)motionRefresh:(id)sender {
    
    // compute the device yaw from the attitude quaternion
    // http://en.wikipedia.org/wiki/Conversion_between_quaternions_and_Euler_angles
    CMQuaternion quat = self.motionManager.deviceMotion.attitude.quaternion;
    double yaw = asin(2*(quat.x*quat.z - quat.w*quat.y));
    // TODO improve the yaw interval (stuck to [-PI/2, PI/2] due to arcsin definition
    
    yaw *= -1;      // reverse the angle so that it reflect a *liquid-like* behavior
    yaw += M_PI_2;  // because for the motion manager 0 is the calibration value (but for us 0 is the horizontal axis)
    
    if (self.motionLastYaw == 0) {
        self.motionLastYaw = yaw;
    }
    
    // kalman filtering
    static float q = 0.1;   // process noise
    static float r = 0.1;   // sensor noise
    static float p = 0.1;   // estimated error
    static float k = 0.5;   // kalman filter gain
    
    float x = self.motionLastYaw;
    p = p + q;
    k = p / (p + r);
    x = x + k*(yaw - x);
    p = (1 - k)*p;
    self.motionLastYaw = x;
}




































- (void)DPMeterView {
    // UIApperance
    [[DPMeterView appearance] setTrackTintColor:[UIColor lightGrayColor]];
    [[DPMeterView appearance] setProgressTintColor:[UIColor darkGrayColor]];
    
    [self.shapeView setShape:[UIBezierPath coldDrinkShape:self.shapeView.frame].CGPath];
    self.shapeView.progressTintColor = [UIColor colorWithRed:76/255.f green:116/255.f blue:206/255.f alpha:1.f];
    
    // swith on the gravity
    __block BOOL flag = true;
    [self.shapeView startGravity:^(double yaw) {
        NSLog(@"yaw %lf", yaw);
        if (yaw > .7 && flag) {
            flag = false;
           [self.shapeView minus:fabs(-0.4) animated:YES];
        }
    }];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    [self updateProgressWithDelta:0.7 animated:YES];
}

- (NSUInteger)supportedInterfaceOrientations
{
    return UIInterfaceOrientationMaskPortrait;
}

- (NSArray *)shapeViews
{
    NSMutableArray *shapeViews = [NSMutableArray array];
    
    NSArray *candidateViews = @[self.shapeView];
    
    for (UIView *view in candidateViews) {
        if ([view isKindOfClass:[DPMeterView class]]) {
            [shapeViews addObject:view];
        }
    }
    
    return [NSArray arrayWithArray:shapeViews];
}

- (void)updateProgressWithDelta:(CGFloat)delta animated:(BOOL)animated
{
    NSArray *shapeViews = [self shapeViews];
    for (DPMeterView *shapeView in shapeViews) {
        if (delta < 0) {
            [shapeView minus:fabs(delta) animated:animated];
        } else {
            [shapeView add:fabs(delta) animated:animated];
        }
    }
    
    self.title = [NSString stringWithFormat:@"%.2f%%",
                  [(DPMeterView *)[shapeViews lastObject] progress]*100];
}

- (IBAction)minus:(id)sender
{
    [self updateProgressWithDelta:-0.1 animated:YES];
}

- (IBAction)add:(id)sender
{
    [self updateProgressWithDelta:+0.1 animated:YES];
}

//- (IBAction)orientationHasChanged:(id)sender
//{
//    CGFloat value = self.orientationSlider.value;
//    CGFloat angle = (M_PI/180) * value;
//    self.orientationLabel.text = [NSString stringWithFormat:@"orientation (%.0f°)", value];
//    
//    for (DPMeterView *v in [self shapeViews]) {
//        [v setGradientOrientationAngle:angle];
//    }
//}
//
//- (IBAction)toggleGravity:(id)sender
//{
//    for (DPMeterView *shapeView in [self shapeViews]) {
//        if ([self.gravitySwitch isOn] && ![shapeView isGravityActive]) {
//            [shapeView startGravity];
//        } else if (![self.gravitySwitch isOn] && [shapeView isGravityActive]) {
//            [shapeView stopGravity];
//        }
//    }
//}

@end
