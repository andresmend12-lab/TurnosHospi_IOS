import SwiftUI

// Esto habilita el gesto de "swipe back" incluso con la barra de navegación oculta
extension UINavigationController: UIGestureRecognizerDelegate {
    override open func viewDidLoad() {
        super.viewDidLoad()
        interactivePopGestureRecognizer?.delegate = self
    }

    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        // Solo permite el gesto si hay más de una vista en la pila
        return viewControllers.count > 1
    }
}
