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
    
    cv::Mat baseImage32FC1;
}

@property (weak, nonatomic) IBOutlet UIImageView *cameraImgView;
@property (weak, nonatomic) IBOutlet UIImageView *subtractImgView;
@property (weak, nonatomic) IBOutlet UIImageView *topRightImgView;
@property (weak, nonatomic) IBOutlet UIImageView *bottomLeftImgView;

@property (assign, nonatomic) NSInteger counter;
@property (assign, nonatomic) BOOL started;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    camera = [[CvVideoCamera alloc] initWithParentView: _cameraImgView];
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
    if (!self.started) {
        return;
    }
    
    cv::Mat rgbImage;
    cv::cvtColor(inputImage, rgbImage, CV_BGR2RGB);
    
    cv::Mat denoisedRGBImage;
    cv::blur(rgbImage, denoisedRGBImage, cv::Size(4, 4));
//    cv::GaussianBlur(OMRImageGray, blurImage, cv::Size(2,2), 0, 0);
    
    cv::Mat denoisedRGBImage32F;
    denoisedRGBImage.convertTo(denoisedRGBImage32F, CV_32F);
    
    cv::Mat grayImage32FC1;
    cv::cvtColor(denoisedRGBImage32F, grayImage32FC1, CV_RGB2GRAY);
    
    if (self.counter == 0) {
        self.started = NO;
        self.counter++;
        colorBaseImage = denoisedRGBImage;
        cv::Mat::MSize reqdSize = colorBaseImage.size;
        int height = *reqdSize.p;
        reqdSize.p++;
        int width = *reqdSize.p;
        
        int beachImgWidth = beachImage.cols;
        int beachImgHeight = beachImage.rows;
        
        cv::Rect roi((beachImgWidth - width) / 2.0 , (beachImgHeight - height) / 2.0, width, height);
        beachImage = beachImage(roi);
        cv::cvtColor(beachImage, beachImage, CV_BGR2RGB);
        
        dispatch_async(dispatch_get_main_queue(), ^{
            self.subtractImgView.image = [ImageUtils UIImageFromCVMat:colorBaseImage];
        });
        
        baseImage32FC1 = grayImage32FC1;
    }
    else {
        self.started = NO;
        cv::Point2d shiftedPoint = cv::phaseCorrelate(grayImage32FC1, baseImage32FC1);
        shiftedPoint = cv::Point2d(-shiftedPoint.x, -shiftedPoint.y);
        NSLog(@"Point x = %lf, y = %lf", shiftedPoint.x, shiftedPoint.y);
        
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
        beachImage.copyTo(bgImage, invertedThresholdImage);
        
        cv::Mat requiredImage;
        cv::add(foregroundImage, bgImage, requiredImage);
        
//        dispatch_async(dispatch_get_main_queue(), ^{
//            self.subtractImgView.image = [ImageUtils UIImageFromCVMat:requiredImage];
//        });
        
        cv::Mat offsetBaseImage = [self offsetBaseImageBy:shiftedPoint];
//        dispatch_async(dispatch_get_main_queue(), ^{
//            self.bottomLeftImgView.image = [ImageUtils UIImageFromCVMat:offsetBaseImage];
//        });
    }
}

- (cv::Mat)offsetBaseImageBy:(cv::Point2d)offsetPoint {
//    cv::Mat offsetBaseImage = cv::Mat::zeros(640, 480, colorBaseImage.type());
//    double absX = abs(offsetPoint.x);
//    double absY = abs(offsetPoint.y);
//    cv::Rect roi = cv::Rect(0, 0, offsetBaseImage.cols - absY, offsetBaseImage.rows - absX);
//    colorBaseImage.copyTo(offsetBaseImage(roi));
//    return offsetBaseImage;
    
//    int shiftCol = offsetPoint.y;
//    int shiftRow = offsetPoint.x;
//    
//    cv::Rect source = cv::Rect(max(0,-shiftCol),max(0,-shiftRow), colorBaseImage.cols-abs(shiftCol),colorBaseImage.rows-abs(shiftRow));
//    
//    cv::Rect target = cv::Rect(max(0,shiftCol),max(0,shiftRow),colorBaseImage.cols-abs(shiftCol),colorBaseImage.rows-abs(shiftRow));
//    
//    cv::Mat outputImg;
//    colorBaseImage(source).copyTo(outputImg(target));
//    return outputImg;
    
    int offsetX = offsetPoint.x;
    int offsetY = offsetPoint.y;
    cv::Mat padded = Mat(colorBaseImage.rows + 2 * abs(offsetY), colorBaseImage.cols + 2 * abs(offsetX), CV_8UC3, cv::Scalar(0,0,0));
    int adjustedX = (offsetX < 0) ? 0 : offsetX;
    int adjustedY = (offsetY < 0) ? 0 : offsetY;
    colorBaseImage.copyTo(padded(cv::Rect(adjustedX, adjustedY, colorBaseImage.cols, colorBaseImage.rows)));
    cv::Mat::MSize reqdSize = padded.size;
    int height = *reqdSize.p;
    reqdSize.p++;
    int width = *reqdSize.p;
    NSLog(@"Reqd Mat 2 = %d, %d", height, width);
   
    adjustedX = (offsetX < 0) ? -offsetX : 0;
    adjustedY = (offsetY < 0) ? -offsetY : 0;
    cv::Mat reqdMat = Mat(padded,cv::Rect(adjustedX, adjustedY, colorBaseImage.cols, colorBaseImage.rows));
    reqdSize = reqdMat.size;
    height = *reqdSize.p;
    reqdSize.p++;
    width = *reqdSize.p;
    NSLog(@"Reqd Mat = %d, %d", height, width);
    
    dispatch_async(dispatch_get_main_queue(), ^{
        self.topRightImgView.image = [ImageUtils UIImageFromCVMat:padded];
        self.bottomLeftImgView.image = [ImageUtils UIImageFromCVMat:reqdMat];
    });
    
    return reqdMat;
}
//Mat offsetImageWithPadding(Const Mat& originalImage, int offsetX, int offsetY, Scalar backgroundColour){
//    padded = Mat(originalImage.rows + 2 * abs(offsetY), originalImage.cols + 2 * abs(offsetX), CV_8UC3, backgroundColour);
//    originalImage.copyTo(padded(Rect(abs(offsetX), abs(offsetY), originalImage.cols, originalImage.rows)));
//    return Mat(padded,Rect(abs(offsetX) + offsetX, abs(offsetY) + offsetY, originalImage.cols, originalImage.rows));
//}

////example use with black borders along the right hand side and top:
//Mat offsetImage = offsetImageWithPadding(originalImage, -10, 6, Scalar(0,0,0));

- (IBAction)btnTapped:(id)sender {
    self.started = YES;
}

@end

