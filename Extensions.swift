import SwiftUI
import UIKit
import ObjectiveC

private final class SwipeBackGestureDelegate: NSObject, UIGestureRecognizerDelegate {
    weak var navigationController: UINavigationController?
    
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        (navigationController?.viewControllers.count ?? 0) > 1
    }
}

private var swipeDelegateKey: UInt8 = 0

extension UINavigationController {
    private var swipeBackDelegate: SwipeBackGestureDelegate {
        if let existing = objc_getAssociatedObject(self, &swipeDelegateKey) as? SwipeBackGestureDelegate {
            existing.navigationController = self
            return existing
        }
        let delegate = SwipeBackGestureDelegate()
        delegate.navigationController = self
        objc_setAssociatedObject(self, &swipeDelegateKey, delegate, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        return delegate
    }
    
    open override func viewDidLoad() {
        super.viewDidLoad()
        interactivePopGestureRecognizer?.delegate = swipeBackDelegate
    }
}
