import UIKit.UIGestureRecognizerSubclass

@available(iOS 9.0, *)
internal class ForceTouchGestureRecognizer: UIGestureRecognizer {
    internal private(set) var force: CGFloat = 0.0
    internal var maximumForce: CGFloat = 4.0
    private var calmDownForNextTouch = false

    func cancel() {
        self.state = .cancelled
        calmDownForNextTouch = true
    }

    convenience init() {
        self.init(target: nil, action: nil)
    }

    internal override init(target: Any?, action: Selector?) {
        super.init(target: target, action: action)
        cancelsTouchesInView = false
    }

    internal override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        calmDownForNextTouch = false
        super.touchesBegan(touches, with: event)
        normalizeForceAndFireEvent(.began, touches: touches)
    }

    internal override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        if (calmDownForNextTouch) {
            return
        }
        super.touchesMoved(touches, with: event)
        normalizeForceAndFireEvent(.changed, touches: touches)
    }


    internal override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesEnded(touches, with: event)
        normalizeForceAndFireEvent(.ended, touches: touches)
    }

    internal override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        calmDownForNextTouch = false
        super.touchesCancelled(touches, with: event)
        normalizeForceAndFireEvent(.cancelled, touches: touches)
    }

    private func normalizeForceAndFireEvent(_ state: UIGestureRecognizer.State, touches: Set<UITouch>) {

        if calmDownForNextTouch || (self.state == .cancelled && state != .began) {
            return
        }

        guard let firstTouch = touches.first else {
            return
        }

        maximumForce = min(firstTouch.maximumPossibleForce, maximumForce)

        force = firstTouch.force / maximumForce
        self.state = state
    }

    internal override func reset() {
        super.reset()
        force = 0.0
    }
}
