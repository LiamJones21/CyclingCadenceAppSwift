//
//  TextFieldAlert.swift
//  CyclingCadenceApp
//
//  Created by Jones, Liam on 11/6/24.
//


import SwiftUI
import UIKit

struct TextFieldAlert {
    let title: String
    let message: String?
    let action: (String?) -> Void
}

extension TextFieldAlert: UIViewControllerRepresentable {
    func makeUIViewController(context: UIViewControllerRepresentableContext<TextFieldAlert>) -> UIViewController {
        UIViewController() // Empty view controller host
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        guard context.coordinator.alert == nil else { return }
        
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addTextField { textField in
            textField.placeholder = "New session name"
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in
            action(nil)
        })
        alert.addAction(UIAlertAction(title: "Save", style: .default) { _ in
            action(alert.textFields?.first?.text)
        })
        
        context.coordinator.alert = alert
        DispatchQueue.main.async {
            uiViewController.present(alert, animated: true, completion: nil)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject {
        var alert: UIAlertController?
    }
}
