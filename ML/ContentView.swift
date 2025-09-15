//
//  ContentView.swift
//  ML
//
//  Created by adithyan na on 13/9/25.
//

import SwiftUI
import ARKit
import Vision

class ARMLViewModel: ObservableObject {
    @Published var detectedObject: String = "No object detected"
    private var visionModel: VNCoreMLModel?
    private var lastClassificationDate = Date()

    init() {
        // Load MobileNetV2 model
        guard let modelURL = Bundle.main.url(forResource: "MobileNetV2", withExtension: "mlmodelc"),
              let coreMLModel = try? MLModel(contentsOf: modelURL) else {
            print("Failed to load Core ML model")
            return
        }

        visionModel = try? VNCoreMLModel(for: coreMLModel)
        print("Core ML model loaded successfully")
    }

    func classifyFrame(_ frame: ARFrame) {
        // Limit classification to once every 0.7 seconds (adjust as needed)
        guard Date().timeIntervalSince(lastClassificationDate) > 0.7 else { return }
        lastClassificationDate = Date()

        guard let visionModel = visionModel else {
            print("Vision model not available")
            return
        }

        let pixelBuffer = frame.capturedImage

        let request = VNCoreMLRequest(model: visionModel) { request, error in
            if let error = error {
                print("Vision request error: \(error.localizedDescription)")
                return
            }

            guard let results = request.results as? [VNClassificationObservation], !results.isEmpty else {
                print("No classification results")
                DispatchQueue.main.async {
                    self.detectedObject = "No object detected"
                }
                return
            }

            let topResult = results.first!
            print("Classified object: \(topResult.identifier) - Confidence: \(topResult.confidence)")

            DispatchQueue.main.async {
                let descriptions = results.map { "\($0.identifier): \($0.confidence)" }
                print("All Results: ", descriptions)
                if let top = results.first {
                    self.detectedObject = "\(top.identifier) (\(Int(top.confidence * 100))%)"
                } else {
                    self.detectedObject = "No object detected"
                }
            }

        }

        request.imageCropAndScaleOption = .centerCrop

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try handler.perform([request])
            } catch {
                print("Failed to perform classification.\n\(error.localizedDescription)")
            }
        }
    }
}

struct ARMLView: UIViewRepresentable {
    @ObservedObject var viewModel: ARMLViewModel

    func makeUIView(context: Context) -> ARSCNView {
        let arView = ARSCNView()
        arView.delegate = context.coordinator
        let configuration = ARWorldTrackingConfiguration()
        arView.session.run(configuration)
        return arView
    }

    func updateUIView(_ uiView: ARSCNView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self, viewModel: viewModel)
    }

    class Coordinator: NSObject, ARSCNViewDelegate {
        var parent: ARMLView
        var viewModel: ARMLViewModel

        init(_ parent: ARMLView, viewModel: ARMLViewModel) {
            self.parent = parent
            self.viewModel = viewModel
        }

        func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
            guard let frame = (renderer as? ARSCNView)?.session.currentFrame else { return }
            viewModel.classifyFrame(frame)
        }
    }
}

struct ContentView: View {
    @StateObject private var viewModel = ARMLViewModel()

    var body: some View {
        VStack {
            ARMLView(viewModel: viewModel)
                .edgesIgnoringSafeArea(.all)
            Text(viewModel.detectedObject)
                .padding()
                .background(Color.black.opacity(0.6))
                .foregroundColor(.white)
        }
    }
}
