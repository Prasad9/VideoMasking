//
//  ViewController.m
//  VideoMasking
//
//  Created by Prasad Pai on 5/4/16.
//  Copyright © 2016 YMedia Labs. All rights reserved.
//


//opencv

#import "ViewController.h"
#import "ImageUtils.h"
#import <opencv2/highgui/ios.h>

using namespace cv;
using namespace std;

@interface ViewController () <CvVideoCameraDelegate>
{
    CvVideoCamera *camera;
    
    cv::Mat colorBaseImage;
    cv::Mat beachImage;
    cv::Mat mountainImage;
    cv::Mat filteringBgImage;
}

@property (weak, nonatomic) IBOutlet UIImageView *cameraImgView;
@property (weak, nonatomic) IBOutlet UIButton *baseImageBtn;
@property (weak, nonatomic) IBOutlet UIButton *beachImageBtn;
@property (weak, nonatomic) IBOutlet UIButton *mountainImageBtn;
@property (weak, nonatomic) IBOutlet UIButton *recordImageBtn;
@property (weak, nonatomic) IBOutlet UILabel *instructionLabel;

@property (assign, nonatomic) NSInteger counter;
@property (assign, nonatomic) BOOL started;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    camera = [[CvVideoCamera alloc] init];
    camera.defaultAVCaptureDevicePosition = AVCaptureDevicePositionFront;
    camera.defaultAVCaptureSessionPreset = AVCaptureSessionPreset640x480;
    camera.defaultAVCaptureVideoOrientation = AVCaptureVideoOrientationPortrait;
    camera.defaultFPS = 30;
    camera.grayscaleMode = NO;
    camera.delegate = self;
    
    self.started = NO;
    self.counter = 0;
    
    UIImage *beach = [UIImage imageNamed:@"beach"];
    beachImage = [ImageUtils cvMatFromUIImage:beach];
    UIImage *mountain = [UIImage imageNamed:@"mountain"];
    mountainImage = [ImageUtils cvMatFromUIImage:mountain];
    self.beachImageBtn.hidden = true;
    self.mountainImageBtn.hidden = true;
    self.recordImageBtn.hidden = true;
    self.instructionLabel.text = @"Take background image";
    [self.baseImageBtn setTitle:@"Click" forState:UIControlStateNormal];
}

-(void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear: animated];
    [camera start];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Video Camera Delegate methods
-(void)processImage:(cv::Mat &)inputImage
{
    cv::Mat rgbImage;
    cv::cvtColor(inputImage, rgbImage, CV_BGR2RGB);
    
    if (!self.started) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.cameraImgView.image = [ImageUtils UIImageFromCVMat:rgbImage];
        });
        return;
    }
    
    cv::Mat denoisedRGBImage;
    cv::blur(rgbImage, denoisedRGBImage, cv::Size(4, 4));
//    cv::GaussianBlur(OMRImageGray, blurImage, cv::Size(2,2), 0, 0);
    
    if (self.counter == 0) {
        self.started = NO;
        self.counter++;
        colorBaseImage = denoisedRGBImage;
        
        dispatch_async(dispatch_get_main_queue(), ^{
            self.cameraImgView.image = [ImageUtils UIImageFromCVMat:colorBaseImage];
            [self.baseImageBtn setTitle:@"Reset" forState:UIControlStateNormal];
            self.beachImageBtn.hidden = NO;
            self.mountainImageBtn.hidden = NO;
            self.instructionLabel.text = @"Select Background mode";
        });
        
    }
    else {
        cv::Mat subImage;
        cv::absdiff(denoisedRGBImage, colorBaseImage, subImage);
        
        cv::Mat grayImage;
        cv::cvtColor(subImage, grayImage, CV_RGB2GRAY);
        
        cv::Mat denoisedGrayImage;
        cv::blur(grayImage, denoisedGrayImage, cv::Size(4, 4));
        
        cv::Mat thresholdImage;
        cv::threshold(denoisedGrayImage, thresholdImage, 10, 255, 0);
        
        cv::Mat foregroundImage;
        denoisedRGBImage.copyTo(foregroundImage, thresholdImage);
        
        cv::Mat invertedThresholdImage = 255 - thresholdImage;
        cv::Mat bgImage;
        filteringBgImage.copyTo(bgImage, invertedThresholdImage);
        
        cv::Mat requiredImage;
        cv::add(foregroundImage, bgImage, requiredImage);
        
        dispatch_async(dispatch_get_main_queue(), ^{
            self.cameraImgView.image = [ImageUtils UIImageFromCVMat:requiredImage];
        });
    }
}

#pragma mark - Action and Selector methods
- (IBAction)baseBtnTapped:(id)sender {
    if ([self.beachImageBtn isHidden]) {
        self.started = YES;
    }
    else {
        self.counter = 0;
        self.beachImageBtn.hidden = true;
        self.mountainImageBtn.hidden = true;
        self.recordImageBtn.hidden = true;
        self.instructionLabel.text = @"Take background image";
        [self.baseImageBtn setTitle:@"Click" forState:UIControlStateNormal];
    }
}

- (IBAction)beachBtnTapped:(id)sender {
    cv::Mat::MSize reqdSize = colorBaseImage.size;
    int height = *reqdSize.p;
    reqdSize.p++;
    int width = *reqdSize.p;
    
    int beachImgWidth = beachImage.cols;
    int beachImgHeight = beachImage.rows;
    
    
    cv::Rect roi((beachImgWidth - width) / 2.0 , (beachImgHeight - height) / 2.0, width, height);
    filteringBgImage = beachImage(roi);
    cv::cvtColor(filteringBgImage, filteringBgImage, CV_BGR2RGB);
    
    self.instructionLabel.hidden = YES;
    self.started = YES;
}

- (IBAction)mountainBtnTapped:(id)sender {
    cv::Mat::MSize reqdSize = colorBaseImage.size;
    int height = *reqdSize.p;
    reqdSize.p++;
    int width = *reqdSize.p;
    
    int mountainImageWidth = mountainImage.cols;
    int mountainImageHeight = mountainImage.rows;
    
    cv::Rect roi((mountainImageWidth - width) / 2.0 , (mountainImageHeight - height) / 2.0, width, height);
    filteringBgImage = mountainImage(roi);
    cv::cvtColor(filteringBgImage, filteringBgImage, CV_BGR2RGB);
    
    self.instructionLabel.hidden = YES;
    self.started = YES;
}

- (IBAction)recordBtnTapped:(id)sender {
    if (![self.baseImageBtn isHidden]) {
        
    }
    else {
        
        self.baseImageBtn.hidden = YES;
    }
}

@end

