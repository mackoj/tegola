#if os(iOS)
  import AVFoundation
  import SwiftUI
  import UIKit

  /// The live camera of the first piece's one question (46, screen 01): already running when the screen appears, with
  /// one shutter. A shot comes back as a JPEG at most 2048 px on its longest side. Where there's no camera (the
  /// simulator, or no permission), it says so and Type it and Library still work.
  struct CameraView: View {
    let shot: (Data) -> Void
    @State private var camera = Camera()

    var body: some View {
      ZStack(alignment: .bottom) {
        if camera.isRunning {
          CameraPreview(session: camera.session)
        } else {
          Color.black.opacity(0.85)
            .overlay {
              Text("No camera here. Type it, or pick a photo.", bundle: .module)
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding()
            }
        }
        if camera.isRunning {
          Button {
            camera.capture(shot)
          } label: {
            Circle()
              .strokeBorder(.white, lineWidth: 4)
              .frame(width: 68, height: 68)
              .padding(.bottom, 16)
          }
          .accessibilityLabel(Text("Take the photo", bundle: .module))
          .accessibilityIdentifier("firstPiece.shutter")
        }
      }
      .task { await camera.start() }
      .onDisappear { camera.stop() }
    }
  }

  @MainActor @Observable
  final class Camera {
    let session = AVCaptureSession()
    private let output = AVCapturePhotoOutput()
    private var delegate: PhotoDelegate?
    var isRunning = false

    func start() async {
      guard await AVCaptureDevice.requestAccess(for: .video),
        let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
        let input = try? AVCaptureDeviceInput(device: device)
      else { return }
      session.beginConfiguration()
      session.sessionPreset = .photo
      if session.canAddInput(input) { session.addInput(input) }
      if session.canAddOutput(output) { session.addOutput(output) }
      session.commitConfiguration()
      let running = SessionBox(session)
      // startRunning blocks, so it runs off the main thread, on the camera's own queue.
      await withCheckedContinuation { (done: CheckedContinuation<Void, Never>) in
        Self.queue.async {
          running.session.startRunning()
          done.resume()
        }
      }
      isRunning = session.isRunning
    }

    func stop() {
      let running = SessionBox(session)
      Self.queue.async { running.session.stopRunning() }
    }

    private static let queue = DispatchQueue(label: "fr.macko.tegola.camera")

    func capture(_ done: @escaping (Data) -> Void) {
      let delegate = PhotoDelegate { data in
        Task { @MainActor in
          if let data { done(data) }
          self.delegate = nil
        }
      }
      self.delegate = delegate
      output.capturePhoto(with: AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.jpeg]), delegate: delegate)
    }
  }

  /// The session, handed to the camera's queue: AVCaptureSession is thread-safe for start and stop, but not Sendable.
  struct SessionBox: @unchecked Sendable {
    let session: AVCaptureSession
    init(_ session: AVCaptureSession) { self.session = session }
  }

  final class PhotoDelegate: NSObject, AVCapturePhotoCaptureDelegate, @unchecked Sendable {
    let done: (Data?) -> Void

    init(done: @escaping (Data?) -> Void) { self.done = done }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: (any Error)?) {
      done(photo.fileDataRepresentation().flatMap(JPEG.resized))
    }
  }

  struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
      let view = PreviewView()
      view.previewLayer.session = session
      view.previewLayer.videoGravity = .resizeAspectFill
      return view
    }

    func updateUIView(_ view: PreviewView, context: Context) {}

    final class PreviewView: UIView {
      override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
      var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }
  }

  enum JPEG {
    /// Re-encodes an image as JPEG, at most 2048 px on its longest side: what the shelf keeps and the model reads. The
    /// re-encode also drops the original's metadata, location included.
    static func resized(_ data: Data) -> Data? {
      guard let image = UIImage(data: data) else { return nil }
      let longest = max(image.size.width, image.size.height)
      let scale = min(1, 2048 / max(longest, 1))
      let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
      let format = UIGraphicsImageRendererFormat()
      format.scale = 1
      return UIGraphicsImageRenderer(size: size, format: format).jpegData(withCompressionQuality: 0.8) { _ in
        image.draw(in: CGRect(origin: .zero, size: size))
      }
    }
  }
#endif
