import CameraKit
import Foundation
import RenderKit
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif
#if canImport(Photos)
import Photos
#endif

// MARK: - Design Tokens

private enum ReviewDesignTokens {
    static let topBarHeight: CGFloat = 56
    static let bottomBarHeight: CGFloat = 80
    static let formatBadgeCornerRadius: CGFloat = 6
    static let buttonSize: CGFloat = 44
    static let maxZoom: CGFloat = 5.0
}

// MARK: - PhotoReviewView

@MainActor
struct PhotoReviewView: View {
    @ObservedObject var viewModel: PhotoReviewViewModel
    let onDismiss: () -> Void
    let onOpenPhotos: () -> Void

    @State private var currentZoom: CGFloat = 1.0
    @State private var lastZoom: CGFloat = 1.0
    @State private var panOffset: CGSize = .zero
    @State private var lastPanOffset: CGSize = .zero

    @State private var showExportOptions = false
    @State private var showShareOptions = false
    #if canImport(UIKit)
    @State private var shareItem: ShareFileItem?
    #endif

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                imageContent
                bottomBar
            }
        }
        .statusBarHidden(true)
        .confirmationDialog("Export Rendered Image", isPresented: $showExportOptions) {
            Button("JPEG (Display P3)") {
                Task { await viewModel.exportJPEG() }
            }
            Button("TIFF 16-bit (Display P3)") {
                Task { await viewModel.exportTIFF() }
            }
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog("Share Rendered Image", isPresented: $showShareOptions) {
            Button("Share JPEG") {
                Task {
                    #if canImport(UIKit)
                    if let url = await viewModel.prepareShareJPEG() {
                        shareItem = ShareFileItem(url: url)
                    }
                    #endif
                }
            }
            Button("Share TIFF") {
                Task {
                    #if canImport(UIKit)
                    if let url = await viewModel.prepareShareTIFF() {
                        shareItem = ShareFileItem(url: url)
                    }
                    #endif
                }
            }
            Button("Cancel", role: .cancel) {}
        }
        #if canImport(UIKit)
        .sheet(item: $shareItem) { item in
            ShareSheet(activityItems: [item.url])
        }
        #endif
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: ReviewDesignTokens.buttonSize, height: ReviewDesignTokens.buttonSize)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close")

            Spacer()

            formatBadge

            Spacer()

            // Balance spacer for the close button
            Color.clear
                .frame(width: ReviewDesignTokens.buttonSize, height: ReviewDesignTokens.buttonSize)
        }
        .padding(.horizontal, 12)
        .frame(height: ReviewDesignTokens.topBarHeight)
        .background(.black.opacity(0.6))
    }

    private var formatBadge: some View {
        Text(formatLabel)
            .font(.system(size: 11, weight: .bold, design: .monospaced))
            .foregroundStyle(formatColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: ReviewDesignTokens.formatBadgeCornerRadius)
                    .fill(formatColor.opacity(0.15))
            )
            .overlay(
                RoundedRectangle(cornerRadius: ReviewDesignTokens.formatBadgeCornerRadius)
                    .stroke(formatColor.opacity(0.4), lineWidth: 1)
            )
    }

    private var formatLabel: String {
        switch viewModel.captureFormat {
        case .processed: return "JPG"
        case .raw: return "RAW"
        case .appleProRAW: return "PRO"
        }
    }

    private var formatColor: Color {
        switch viewModel.captureFormat {
        case .processed: return .white.opacity(0.7)
        case .raw: return .green
        case .appleProRAW: return .orange
        }
    }

    // MARK: - Image Content

    private var imageContent: some View {
        GeometryReader { geometry in
            ZStack {
                imageView(in: geometry)

                if viewModel.isRendering {
                    renderingOverlay
                }

                if viewModel.renderError != nil {
                    renderErrorOverlay
                }
            }
            .clipped()
        }
    }

    // MARK: - Image View

    /// Shows the rendered RAW image when available, otherwise the processed JPEG.
    private func imageView(in geometry: GeometryProxy) -> some View {
        Group {
            if let displayImage = viewModel.displayImage {
                Image(uiImage: displayImage)
                    .resizable()
                    .scaledToFit()
                    .scaleEffect(currentZoom)
                    .offset(panOffset)
                    .gesture(zoomGesture)
                    .gesture(panGesture)
                    .onTapGesture(count: 2) { toggleZoom(in: geometry) }
            } else {
                Color.black
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Rendering State Overlays

    private var renderingOverlay: some View {
        VStack(spacing: 12) {
            ProgressView()
                .tint(.white)
            Text("Rendering RAW...")
                .font(.caption.weight(.medium))
                .foregroundStyle(.white.opacity(0.7))
        }
        .padding(20)
        .background(.black.opacity(0.6), in: RoundedRectangle(cornerRadius: 12))
    }

    private var renderErrorOverlay: some View {
        VStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 24))
                .foregroundStyle(.orange)
            Text(viewModel.renderError ?? "Render failed")
                .font(.caption.weight(.medium))
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .padding(20)
        .background(.black.opacity(0.6), in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        HStack(spacing: 24) {
            // Export button (only for RAW/ProRAW captures with a rendered image)
            Button {
                if viewModel.canExport {
                    showExportOptions = true
                }
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: "square.and.arrow.down")
                        .font(.system(size: 20, weight: .medium))
                    Text("Export")
                        .font(.system(size: 10, weight: .medium))
                }
                .foregroundStyle(viewModel.canExport ? .white.opacity(0.8) : .white.opacity(0.3))
                .frame(width: ReviewDesignTokens.buttonSize, height: ReviewDesignTokens.buttonSize)
            }
            .buttonStyle(.plain)
            .disabled(!viewModel.canExport)
            .accessibilityLabel("Export")
            .accessibilityHint("Export rendered RAW as JPEG or TIFF")

            Button {
                if viewModel.canExport {
                    showShareOptions = true
                }
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 20, weight: .medium))
                    Text("Share")
                        .font(.system(size: 10, weight: .medium))
                }
                .foregroundStyle(viewModel.canExport ? .white.opacity(0.8) : .white.opacity(0.3))
                .frame(width: ReviewDesignTokens.buttonSize, height: ReviewDesignTokens.buttonSize)
            }
            .buttonStyle(.plain)
            .disabled(!viewModel.canExport)
            .accessibilityLabel("Share")
            .accessibilityHint("Share rendered RAW as JPEG or TIFF")

            Spacer()

            // Export status
            if viewModel.isExporting {
                ProgressView()
                    .tint(.white)
            } else if let exportMessage = viewModel.exportMessage {
                Text(exportMessage)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white.opacity(0.7))
                    .transition(.opacity)
            }

            Spacer()

            // Open in Photos button
            Button(action: onOpenPhotos) {
                VStack(spacing: 4) {
                    Image(systemName: "photo.on.rectangle")
                        .font(.system(size: 20, weight: .medium))
                    Text("Photos")
                        .font(.system(size: 10, weight: .medium))
                }
                .foregroundStyle(.white.opacity(0.8))
                .frame(width: ReviewDesignTokens.buttonSize, height: ReviewDesignTokens.buttonSize)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Open in Photos")
        }
        .padding(.horizontal, 24)
        .frame(height: ReviewDesignTokens.bottomBarHeight)
        .background(.black.opacity(0.6))
    }

    // MARK: - Gestures

    private var zoomGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                let newZoom = lastZoom * value.magnification
                currentZoom = min(max(newZoom, 1.0), ReviewDesignTokens.maxZoom)
            }
            .onEnded { value in
                let newZoom = lastZoom * value.magnification
                currentZoom = min(max(newZoom, 1.0), ReviewDesignTokens.maxZoom)
                lastZoom = currentZoom
                if currentZoom <= 1.0 {
                    resetZoomState()
                }
            }
    }

    private var panGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                guard currentZoom > 1.0 else { return }
                panOffset = CGSize(
                    width: lastPanOffset.width + value.translation.width,
                    height: lastPanOffset.height + value.translation.height
                )
            }
            .onEnded { _ in
                lastPanOffset = panOffset
            }
    }

    private func toggleZoom(in geometry: GeometryProxy) {
        withAnimation(.easeInOut(duration: 0.3)) {
            if currentZoom > 1.0 {
                resetZoomState()
            } else {
                currentZoom = 2.0
                lastZoom = 2.0
            }
        }
    }

    private func resetZoomState() {
        currentZoom = 1.0
        lastZoom = 1.0
        panOffset = .zero
        lastPanOffset = .zero
    }
}

// MARK: - PhotoReviewViewModel

@MainActor
final class PhotoReviewViewModel: ObservableObject {
    @Published private(set) var processedImage: UIImage?
    @Published private(set) var renderedImage: UIImage?
    @Published private(set) var isRendering = false
    @Published private(set) var renderError: String?
    @Published private(set) var renderDurationMs: Int?
    @Published private(set) var isExporting = false
    @Published private(set) var exportMessage: String?

    let captureFormat: CapturePhotoFormat
    let payload: CapturedPhotoPayload

    private let renderer: any RawRendering
    private let exporter: any RenderExporting
    private var renderResult: RenderResult?
    private var exportMessageDismissTask: Task<Void, Never>?

    /// The image to display — rendered RAW if available, otherwise processed JPEG.
    var displayImage: UIImage? {
        renderedImage ?? processedImage
    }

    /// Whether the rendered image is ready for export.
    var canExport: Bool {
        renderedImage != nil && renderResult != nil
    }

    /// Whether RAW rendering should be attempted for this capture format.
    private var isRawFormat: Bool {
        switch captureFormat {
        case .raw, .appleProRAW: return true
        case .processed: return false
        }
    }

    init(
        payload: CapturedPhotoPayload,
        captureFormat: CapturePhotoFormat,
        renderer: any RawRendering,
        exporter: any RenderExporting
    ) {
        self.payload = payload
        self.captureFormat = captureFormat
        self.renderer = renderer
        self.exporter = exporter

        // Load processed image immediately
        if let processedData = payload.processedData,
           let image = UIImage(data: processedData) {
            self.processedImage = image
        }
    }

    /// Start async rendering of the RAW DNG data.
    func startRendering() {
        guard isRawFormat else { return }
        guard let rawData = payload.rawData else {
            renderError = "No RAW data available."
            return
        }

        isRendering = true
        renderError = nil

        Task {
            do {
                // Render at screen resolution for performance
                let screenScale = UIScreen.main.scale
                let screenBounds = UIScreen.main.bounds
                let targetSize = CGSize(
                    width: screenBounds.width * screenScale,
                    height: screenBounds.height * screenScale
                )

                let result = try await renderer.render(
                    dngData: rawData,
                    profile: .neutral,
                    targetSize: targetSize
                )

                self.renderResult = result
                self.renderDurationMs = result.totalDurationMilliseconds

                // Convert CIImage to UIImage for display
                let context = CIContext()
                if let cgImage = context.createCGImage(result.image, from: result.image.extent) {
                    self.renderedImage = UIImage(cgImage: cgImage)
                } else {
                    self.renderError = "Failed to create display image."
                }

                self.isRendering = false
            } catch {
                self.renderError = error.localizedDescription
                self.isRendering = false
            }
        }
    }

    /// Export the rendered RAW as JPEG.
    func exportJPEG() async {
        guard let renderResult else { return }
        isExporting = true
        exportMessage = nil

        do {
            let jpegData = try await exporter.exportJPEG(from: renderResult, quality: 0.95)
            await saveToPhotos(data: jpegData, uti: "public.jpeg")
            showExportSuccess(format: "JPEG", byteCount: jpegData.count)
        } catch {
            exportMessage = "Export failed: \(error.localizedDescription)"
        }

        isExporting = false
    }

    /// Export the rendered RAW as TIFF.
    func exportTIFF() async {
        guard let renderResult else { return }
        isExporting = true
        exportMessage = nil

        do {
            let tiffData = try await exporter.exportTIFF(from: renderResult)
            await saveToPhotos(data: tiffData, uti: "public.tiff")
            showExportSuccess(format: "TIFF", byteCount: tiffData.count)
        } catch {
            exportMessage = "Export failed: \(error.localizedDescription)"
        }

        isExporting = false
    }

    #if canImport(Photos)
    private func saveToPhotos(data: Data, uti: String) async {
        do {
            try await PHPhotoLibrary.shared().performChanges {
                let request = PHAssetCreationRequest.forAsset()
                let options = PHAssetResourceCreationOptions()
                options.uniformTypeIdentifier = uti
                request.addResource(with: .photo, data: data, options: options)
            }
        } catch {
            exportMessage = "Save failed: \(error.localizedDescription)"
        }
    }
    #else
    private func saveToPhotos(data: Data, uti: String) async {
        exportMessage = "Photos not available."
    }
    #endif

    private func showExportSuccess(format: String, byteCount: Int) {
        let sizeMB = Double(byteCount) / 1_048_576.0
        exportMessage = "\(format) saved (\(String(format: "%.1f", sizeMB)) MB)"
        exportMessageDismissTask?.cancel()
        exportMessageDismissTask = Task {
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            exportMessage = nil
        }
    }

    /// Exports to a temporary JPEG and returns the file URL for sharing.
    func prepareShareJPEG() async -> URL? {
        guard let renderResult else { return nil }
        isExporting = true
        exportMessage = nil

        defer { isExporting = false }

        do {
            let data = try await exporter.exportJPEG(from: renderResult, quality: 0.95)
            let url = try writeTemporaryFile(data: data, fileExtension: "jpg")
            exportMessage = "JPEG ready to share"
            return url
        } catch {
            exportMessage = "Share failed: \(error.localizedDescription)"
            return nil
        }
    }

    /// Exports to a temporary TIFF and returns the file URL for sharing.
    func prepareShareTIFF() async -> URL? {
        guard let renderResult else { return nil }
        isExporting = true
        exportMessage = nil

        defer { isExporting = false }

        do {
            let data = try await exporter.exportTIFF(from: renderResult)
            let url = try writeTemporaryFile(data: data, fileExtension: "tiff")
            exportMessage = "TIFF ready to share"
            return url
        } catch {
            exportMessage = "Share failed: \(error.localizedDescription)"
            return nil
        }
    }

    private func writeTemporaryFile(data: Data, fileExtension: String) throws -> URL {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let timestamp = formatter.string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let filename = "photodew-render-\(timestamp).\(fileExtension)"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try data.write(to: url, options: .atomic)
        return url
    }
}

#if canImport(UIKit)
private struct ShareFileItem: Identifiable {
    let id = UUID()
    let url: URL
}

private struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
#endif
