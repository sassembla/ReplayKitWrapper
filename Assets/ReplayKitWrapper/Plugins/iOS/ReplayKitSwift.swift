

import UIKit
import ReplayKit
import Photos
import Accounts


//    プライベートクラスは外部に露出しないため、protocolに合一しても扱うことができる。
private class InnerPreviwViewController: UIViewController, RPPreviewViewControllerDelegate {
    let master:ReplayKitSwift
    
    // setup関数で、レシーバの設定を行う。完了したタイミングでdismissとか。
    init(s:ReplayKitSwift) {
        self.master = s
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    
    // ReplayKitのハンドラ、編集の完了を通知する
    public func previewControllerDidFinish(_ previewController: RPPreviewViewController) {
        previewController.dismiss(animated:true, completion: nil)
        master.recordingStopped()
    }
}

private class ReplayFileUtil {
    // derived from https://github.com/dan12411/ScreenRecord-master/blob/b2e12b79d0b82aeaf6de63a7214fad20220accc6/ScreenRecordDemo/Source/FileUtil.swift

    internal class func createReplaysFolder() {
        let documentDirectoryPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first
        let savePathUrl : NSURL = NSURL(fileURLWithPath: documentDirectoryPath! + "/Replays")

        do { // delete old video
            try FileManager.default.removeItem(at: savePathUrl as URL)
        } catch { print(error.localizedDescription) }
        
        // path to documents directory
        
        if let documentDirectoryPath = documentDirectoryPath {
            // create the custom folder path
            let replayDirectoryPath = documentDirectoryPath.appending("/Replays")
            let fileManager = FileManager.default
            if !fileManager.fileExists(atPath: replayDirectoryPath) {
                do {
                    try fileManager.createDirectory(atPath: replayDirectoryPath,
                                                    withIntermediateDirectories: false,
                                                    attributes: nil)
                } catch {
                    print("Error creating Replays folder in documents dir: \(error)")
                }
            }
        }
    }
    
    internal class func filePath(_ fileName: String, ext: String) -> String {
        createReplaysFolder()
        let paths = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)
        let documentsDirectory = paths[0] as String
        let filePath : String = "\(documentsDirectory)/Replays/\(fileName).\(ext)"
        return filePath
    }
    
    internal class func fetchAllReplays() -> Array<URL> {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        let replayPath = documentsDirectory?.appendingPathComponent("/Replays")
        let directoryContents = try! FileManager.default.contentsOfDirectory(at: replayPath!, includingPropertiesForKeys: nil, options: [])
        return directoryContents
    }
}

private class ScreenCapture {
    var assetWriter:AVAssetWriter!
    var videoInput:AVAssetWriterInput!
    var audioInput:AVAssetWriterInput!
    
    var startSesstion = false

    
    public func startRecording(withFileName fileName: String, ext: String, recordingHandler:@escaping (Error?)-> Void) {
        if #available(iOS 11.0, *) {
            let fileURL = URL(fileURLWithPath: ReplayFileUtil.filePath(fileName, ext:ext))
            print("fileURL", fileURL)
            assetWriter = try! AVAssetWriter(outputURL:fileURL, fileType:AVFileType.mp4)
            let videoOutputSettings: Dictionary<String, Any> = [
                AVVideoCodecKey : AVVideoCodecType.h264,
                AVVideoWidthKey : 100,
                AVVideoHeightKey : 300
                //                AVVideoCompressionPropertiesKey : [
                //                    AVVideoAverageBitRateKey :425000, //96000
                //                    AVVideoMaxKeyFrameIntervalKey : 1
                //                ]
            ];
            
            var channelLayout = AudioChannelLayout.init()
            channelLayout.mChannelLayoutTag = kAudioChannelLayoutTag_MPEG_5_1_D
            let audioOutputSettings: [String : Any] = [
                AVNumberOfChannelsKey: 6,
                AVFormatIDKey: kAudioFormatMPEG4AAC_HE,
                AVSampleRateKey: 44100,
                AVChannelLayoutKey: NSData(bytes: &channelLayout, length: MemoryLayout.size(ofValue: channelLayout)),
            ]
            
            
            videoInput  = AVAssetWriterInput(mediaType: AVMediaType.video, outputSettings: videoOutputSettings)
            audioInput  = AVAssetWriterInput(mediaType: AVMediaType.audio, outputSettings: audioOutputSettings)
            
            videoInput.expectsMediaDataInRealTime = true
            audioInput.expectsMediaDataInRealTime = true
            
            assetWriter.add(videoInput)
            assetWriter.add(audioInput)
            
            RPScreenRecorder.shared().startCapture(handler: { (sample, bufferType, error) in recordingHandler(error)
                
                if CMSampleBufferDataIsReady(sample){
                    DispatchQueue.main.async { [weak self] in
                        if self?.assetWriter.status == AVAssetWriterStatus.unknown {
                            if !(self?.assetWriter.startWriting())! {
                                return
                            }
                            self?.assetWriter.startSession(atSourceTime: CMSampleBufferGetPresentationTimeStamp(sample))
                            self?.startSesstion = true
                        }
                    }
                    
                    if self.assetWriter.status == AVAssetWriterStatus.failed {
                        
                        print("Error occured, status = \(String(describing: self.assetWriter.status.rawValue)), \(String(describing: self.assetWriter.error!.localizedDescription)) \(String(describing: self.assetWriter.error))")
                        recordingHandler(self.assetWriter.error)
                        return
                    }
                    
                    if (bufferType == .video)
                    {
                        if(self.videoInput.isReadyForMoreMediaData) && self.startSesstion {
                            self.videoInput.append(sample)
                        }
                    }
                    
                    if (bufferType == .audioMic)
                    {
                        if self.audioInput.isReadyForMoreMediaData
                        {
                            self.audioInput.append(sample)
                        }
                    }
                }
            }) { (error) in
                recordingHandler(error)
                //                debugPrint(error)
            }
        } else
        {
            // Fallback on earlier versions
        }
    }
    
    func stopRecording(aPathName: String ,handler: @escaping (Error?) -> Void) {
        
        //var isSucessFullsave = false
        if #available(iOS 11.0, *)
        {
            self.startSesstion = false
            RPScreenRecorder.shared().stopCapture{ (error) in
                self.videoInput.markAsFinished()
                self.audioInput.markAsFinished()
                
                handler(error)
                if error == nil{
                    self.assetWriter.finishWriting{
                        self.startSesstion = false
                        print(ReplayFileUtil.fetchAllReplays())
                        self.PhotosSaveWithAurtorise(aPathName: aPathName)
                    }
                    return
                }
                
                print("ファイルが残ったりする。 エラーハンドリングしないと。")
            }
        }else {
            // print("Fallback on earlier versions")
        }
    }
    
    @available(iOS 9.0, *)
    func PhotosSaveWithAurtorise(aPathName: String) {
        if PHPhotoLibrary.authorizationStatus() == .authorized {
            self.SaveToCamera(aPathName: aPathName)
        } else {
            PHPhotoLibrary.requestAuthorization({ (status) in
                if status == .authorized {
                    self.SaveToCamera(aPathName: aPathName)
                }
            })
        }
    }
    
    @available(iOS 9.0, *)
    func SaveToCamera(aPathName: String) {
        PHPhotoLibrary.shared().performChanges({
            //これは先ほど作ったファイルのパスを指す
            let path = ReplayFileUtil.fetchAllReplays().last!
            PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL:path)
        }) { saved, error in
            if saved {
//                addScreenCaptureVideo(aPath: aPathName)
                
                let fetchOptions = PHFetchOptions()
                fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
                
                // After uploading we fetch the PHAsset for most recent video and then get its current location url
                
                let fetchResult = PHAsset.fetchAssets(with: .video, options: fetchOptions).lastObject!
                
                fetchResult.requestContentEditingInput(with: PHContentEditingInputRequestOptions()) { (input, _) in
                    let urlCandidate = (input?.audiovisualAsset as! AVURLAsset).url.absoluteString
                    
                    print("saved", urlCandidate)
                    
                    // url scheme開いて、twitterにpostしたいな〜とか思っている。
                    // まだUntiyからのビルド系の処理は書かれていないため、ファイルアクセスやschemeの許可系の記述がplistに必要。
                    DispatchQueue.main.asyncAfter(
                        deadline: .now() + 1.0,
                        execute: {
                            let url = NSURL(string: "twitter://post")!
                            if (UIApplication.shared.canOpenURL(url as URL)) {
                                UIApplication.shared.openURL(url as URL)
                            }
                        }
                    )
                }
            } else {
                print("error to save ", error as Any)
            }
        }
    }
}

@objc class ReplayKitSwift : UIViewController{
    private let RECORD_LIMIT = 10.0
    private var date:Date!
    
    private var controller:InnerPreviwViewController!
    private let window:UIWindow = ((UIApplication.shared.delegate?.window)!)!
    
    @objc public var isRecording = false
    @objc public var failed = false
    @objc public var failedReason = ""
    
    @available(iOS 11.0, *)
    @objc public func startRecording() -> Void {
        
        let recorder = RPScreenRecorder.shared()
        
        guard recorder.isAvailable else {
            self.failed = true
            self.failedReason = "replayKit recorder is not available."
            return
        }
        
        //マイクを使う(固定)
        recorder.isMicrophoneEnabled = true
        
//      独自録画する場合。
//        let s = ScreenCapture()
//
//        DispatchQueue.main.asyncAfter(
//            deadline: .now() + self.RECORD_LIMIT,
//            execute: {
//                print("stopが呼ばれた")
//                s.stopRecording(aPathName: "dasda", handler: { (e) in
//                    print("ふむ")
//                })
//            }
//        )
//
//        s.startRecording(withFileName: "testCapture", ext:"mp4") { (e) in
//
//        }
//        return
        
        //replayKitでの動画撮影開始
        self.controller = InnerPreviwViewController(s:self)
        recorder.startRecording{ [unowned self] (error) in
            
            guard error == nil else {
                self.failed = true
                self.failedReason = "failed to start recording. error:" + (error?.localizedDescription)!
                return
            }
            
            //録画開始のコールバックやりたい、、
            self.isRecording = true
            self.failed = false
            self.failedReason = ""
        }
    }
    
    /**
        非同期で停止するメソッド。ここに関数渡せるといいね。んでそれを呼ぶ。
     */
    @available(iOS 11.0, *)
    @objc public func stopRecording() -> Void {
        var stopped = false
        
        //定期実行で失敗を検知する
        DispatchQueue.main.asyncAfter(
            deadline: .now() + 5,
            execute: {
                if !stopped {
                    //録画に失敗した。失敗をセットする。
                    self.failed = true
                    self.failedReason = "failed to store recording. sorry."
                }
            }
        )
        
        let recorder = RPScreenRecorder.shared()
        guard recorder.isRecording else {
            self.failed = true
            self.failedReason = "recorder is not recording."
            return
        }
        
        guard recorder.isAvailable else {
            self.failed = true
            self.failedReason = "recorder is not available."
            return
        }
        
        recorder.stopRecording { [unowned self] (preview, error) in
            stopped = true
            
            guard error == nil else {
                self.failed = true
                self.failedReason = "failed to store recording. reason:" + (error?.localizedDescription)!
                return
            }
            
            guard let previewViewController = preview else {
                self.failed = true
                self.failedReason = "recorder is not recording. cannot preview."
                return
            }
            
            //delegateをセット、プレビューの完了時に呼ばれるようになる。
            previewViewController.previewControllerDelegate = self.controller
            
            //比率でpreviewViewControllerを変形させ、
            let safeArea = self.window.safeAreaInsets
            let safeAreaHeight = self.view.frame.height - (safeArea.top + safeArea.bottom)
            let safeAreaWidth = self.view.frame.width - (safeArea.left + safeArea.right)
            let scaleX = safeAreaWidth / self.view.frame.width
            let scaleY = safeAreaHeight / self.view.frame.height
            let scale = min(scaleX, scaleY)
            
            previewViewController.view.transform = CGAffineTransform(scaleX: scale, y: scale)
            self.window.rootViewController?.present(previewViewController, animated: true) {
                // アニメーションさせる
                UIView.animate(withDuration: 1, animations: {
                    previewViewController.view.frame.origin.x += safeArea.left
                    previewViewController.view.frame.origin.y += safeArea.top
                    previewViewController.view.frame.size.width -= safeArea.left + safeArea.right
                    previewViewController.view.frame.size.height -= safeArea.top + safeArea.bottom
                }, completion: nil)
            }
        }
    }
    

    
    public func recordingStopped() {
        self.controller = nil
        
//        録画が完了したので、その旨を伝える。boolの監視でもしてもらうかな。
        isRecording = false
        failed = false
        failedReason = ""
    }
}
