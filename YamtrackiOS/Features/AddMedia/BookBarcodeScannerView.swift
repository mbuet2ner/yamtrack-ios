import SwiftUI

#if canImport(VisionKit)
import Vision
import VisionKit
#endif

struct BookBarcodeScannerView: View {
    let onDetected: @Sendable (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var didEmitSimulatedISBN = false

    private var simulatedISBN: String? {
        ProcessInfo.processInfo.value(after: "-ui-testing-simulated-book-isbn")
    }

    var body: some View {
        Group {
            if let simulatedISBN {
                simulatedScannerContent(isbn: simulatedISBN)
            } else if #available(iOS 16.0, *), scannerIsAvailable {
                liveScannerContent
            } else {
                scannerUnavailableContent
            }
        }
        .navigationTitle("Scan Book Barcode")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") {
                    dismiss()
                }
            }
        }
    }

    private var scannerIsAvailable: Bool {
#if canImport(VisionKit)
        DataScannerViewController.isSupported && DataScannerViewController.isAvailable
#else
        false
#endif
    }

    private func simulatedScannerContent(isbn: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "barcode.viewfinder")
                .font(.system(size: 42, weight: .semibold))
                .foregroundStyle(.tint)

            Text("Simulated barcode scan")
                .font(.title3.weight(.semibold))

            Text("UI tests will immediately use \(isbn).")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
        .onAppear {
            guard !didEmitSimulatedISBN else { return }
            didEmitSimulatedISBN = true
            Task { @MainActor in
                onDetected(isbn)
                dismiss()
            }
        }
    }

    private var liveScannerContent: some View {
#if canImport(VisionKit)
        DataScannerContainer(onDetected: onDetected)
            .ignoresSafeArea()
#else
        scannerUnavailableContent
#endif
    }

    private var scannerUnavailableContent: some View {
        VStack(spacing: 16) {
            Image(systemName: "camera.viewfinder")
                .font(.system(size: 42, weight: .semibold))
                .foregroundStyle(.secondary)

            Text("Barcode scanning needs a supported iPhone camera.")
                .font(.headline.weight(.semibold))
                .multilineTextAlignment(.center)

            Text("Use the search field instead, or try this on a real device.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }
}

#if canImport(VisionKit)
@available(iOS 16.0, *)
private struct DataScannerContainer: UIViewControllerRepresentable {
    let onDetected: @Sendable (String) -> Void

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(
            recognizedDataTypes: [.barcode(symbologies: [.ean13])],
            qualityLevel: .balanced,
            recognizesMultipleItems: false,
            isHighFrameRateTrackingEnabled: false,
            isPinchToZoomEnabled: true,
            isGuidanceEnabled: true,
            isHighlightingEnabled: true
        )
        scanner.delegate = context.coordinator
        DispatchQueue.main.async {
            try? scanner.startScanning()
        }
        return scanner
    }

    func updateUIViewController(_ uiViewController: DataScannerViewController, context: Context) {
        if !uiViewController.isScanning {
            try? uiViewController.startScanning()
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onDetected: onDetected)
    }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        private let onDetected: @Sendable (String) -> Void
        private var hasDeliveredResult = false

        init(onDetected: @escaping @Sendable (String) -> Void) {
            self.onDetected = onDetected
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            guard !hasDeliveredResult else { return }

            for item in addedItems {
                guard case let .barcode(barcode) = item,
                      let payload = barcode.payloadStringValue,
                      !payload.isEmpty
                else {
                    continue
                }

                hasDeliveredResult = true
                onDetected(payload)
                dataScanner.stopScanning()
                break
            }
        }
    }
}
#endif

extension ProcessInfo {
    func value(after flag: String) -> String? {
        guard let index = arguments.firstIndex(of: flag) else {
            return nil
        }

        let valueIndex = arguments.index(after: index)
        guard valueIndex < arguments.endIndex else {
            return nil
        }

        return arguments[valueIndex]
    }
}
