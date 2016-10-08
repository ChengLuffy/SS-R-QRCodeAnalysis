//
//  ViewController.swift
//  QRScan
//
//  Created by 成璐飞 on 2016/10/8.
//  Copyright © 2016年 成璐飞. All rights reserved.
//

import Cocoa

extension String {
    /// Encode a String to Base64
    func toBase64() -> String {
        return Data(self.utf8).base64EncodedString()
    }
    
    /// Decode a String from Base64. Returns nil if unsuccessful.
    func fromBase64() -> String? {
        guard let data = Data(base64Encoded: self) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}

class ViewController: NSViewController {

    @IBOutlet weak var label: NSTextField!
    override func viewDidLoad() {
        super.viewDidLoad()

        NotificationCenter.default.addObserver(forName: NSNotification.Name(rawValue: "NOTIFY_FOUND_SS_URL"), object: nil, queue: nil) {
            (note: Notification) in
            if let userInfo = (note as NSNotification).userInfo {
                let urls: [URL] = userInfo["urls"] as! [URL]
                if urls.count > 0 {
                    let str = urls[0].absoluteString
                    
                    if (str.hasPrefix("ss")) {
                        let dict = ParseSSURL(URL.init(string: str))
                        print(dict)
                        let jsonData = try! JSONSerialization.data(withJSONObject: dict!, options: .prettyPrinted)
                        self.label.stringValue = String(data: jsonData, encoding: .utf8)!
                    } else {
                        self.label.stringValue = "msg:\n     \(str)"
                    }
                } else {
                    self.label.stringValue = "没有找到或者不能清楚识别二维码，您也可以将图片复制或拖到上方区域"
                }
            }
        }

        
        // Do any additional setup after loading the view.
        
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }

    @IBAction func imageWellAction(_ sender: AnyObject) {
        
        
        let imageView = sender as! NSImageView
        let detector = CIDetector.init(ofType: CIDetectorTypeQRCode, context: nil, options: [CIDetectorAccuracy: CIDetectorAccuracyHigh])
        let image = imageView.image
        if let image = image {
            var imageRect:CGRect = CGRect(x: 0, y: 0, width: image.size.width, height: image.size.height)
            let imageRef = image.cgImage(forProposedRect: &imageRect, context: NSGraphicsContext.current(), hints: nil)
            let ciimage = CIImage(cgImage: imageRef!)
            
            let features = detector!.features(in: ciimage)
            if (features.count) > 0 {
                let feature = features.last as! CIQRCodeFeature
                let str = feature.messageString
                print(str)
                if (str?.hasPrefix("ss"))! {
                    let dict = ParseSSURL(URL.init(string: str!))
                    print(dict)
                    let jsonData = try! JSONSerialization.data(withJSONObject: dict!, options: .prettyPrinted)
                    label.stringValue = String(data: jsonData, encoding: .utf8)!
                } else {
                    label.stringValue = "msg:\n     \(str!)"
                }
                
            } else {
                self.label.stringValue = "没有找到或者不能清楚识别二维码，您也可以将图片复制或拖到上方区域"
            }
        }
    }
    
    @IBAction func scanScreen(_ sender: AnyObject) {
        ScanQRCodeOnScreen()
    }
}

