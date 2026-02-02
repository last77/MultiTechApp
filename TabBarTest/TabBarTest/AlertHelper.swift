//
//  AlertHelper.swift
//  TabBarTest
//
//  Created by app on 2026/1/12.
//

import UIKit
class AlertHelper  {
    static func alert(
        title: String,
        confirmHandler: ((UIAlertAction) -> Void)?,
        cancelHandler: ((UIAlertAction) -> Void)?,
        viewController: UIViewController
    ) {

        let alertController = UIAlertController(
            title: title,
            message: nil,
            preferredStyle: .alert
        )

        let confirmAction = UIAlertAction(
            title: "是",
            style: .default,
            handler: confirmHandler
        )

        let cancelAction = UIAlertAction(
            title: "否",
            style: .cancel,
            handler: cancelHandler
        )

        alertController.addAction(confirmAction)
        alertController.addAction(cancelAction)

        viewController.present(alertController, animated: true, completion: nil)

    }
}
