//
//  HomeViewController.swift
//  TabBarTest
//
//  Created by app on 2025/9/25.
//

import UIKit

class HomeViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        testAlert()
        
        let plainHex = "88dd1f15030000000000000000000000000000009C"
        let keyIndex = 0
        
        if let cipherHex = AESCBCUtil.encryptHexStringZeroPadding(plainHex, keyIndex: keyIndex) {
            print("Cipher HEX:", cipherHex)
            
            // 验证解密
            if let back = AESCBCUtil.decryptHexStringZeroPadding("5C21200B83605C92F8CDE34D4DFE7246E595507D1E1BC80B60C61BCE63A103E1", keyIndex: keyIndex) {
                print("Decrypted HEX: length:", back,back.count)
                print(back.uppercased() == plainHex.uppercased() ? "✅ OK" : "❌ Not Match")
            }
        }
        
    }
    
    func testAlert(){
        AlertHelper.alert(title: "11111", confirmHandler: { action in
            print("111111")
        }, cancelHandler: { cancel in
            
        }, viewController: self)
    }
    
    // MARK: - Setup Methods
    
    private func setupUI() {
        view.backgroundColor = .clear
        view.isOpaque = false
        
        // Add background image view
        let bgImageView = UIImageView(frame: view.bounds)
        bgImageView.image = UIImage(named: "home_bg")
        bgImageView.contentMode = .scaleAspectFill
        bgImageView.translatesAutoresizingMaskIntoConstraints = false
        view.insertSubview(bgImageView, at: 0)
        NSLayoutConstraint.activate([
            bgImageView.topAnchor.constraint(equalTo: view.topAnchor),
            bgImageView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            bgImageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bgImageView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        title = "首页"
    }
    
}
