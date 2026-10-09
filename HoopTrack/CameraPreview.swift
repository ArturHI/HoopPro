import SwiftUI
import AVFoundation

/// Live picture from the recorder's camera, for aiming the phone.
///
/// Every `CameraPreview` shows the recorder's one shared layer. Creating a
/// fresh preview layer would reconfigure the camera, and reconfiguring it
/// mid-recording makes iOS end the recording.
struct CameraPreview: UIViewRepresentable {
    let layer: AVCaptureVideoPreviewLayer

    func makeUIView(context: Context) -> HostView {
        let view = HostView()
        view.host(layer)
        return view
    }

    func updateUIView(_ view: HostView, context: Context) {
        view.host(layer)
    }

    final class HostView: UIView {
        private weak var hosted: CALayer?

        func host(_ layer: CALayer) {
            hosted = layer
            if layer.superlayer !== self.layer {
                self.layer.addSublayer(layer)
            }
            setNeedsLayout()
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            // Only size the layer while this view is the one showing it.
            guard let hosted, hosted.superlayer === layer else { return }
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            hosted.frame = bounds
            CATransaction.commit()
        }
    }
}
