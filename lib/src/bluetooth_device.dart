part of bluetooth_printer;

class BluetoothDevice {
  final String name;
  final String address;
  final int type;
  bool _isConnected;
  final BluetoothPrinter _plugin;

  BluetoothDevice._internal({
    required this.name,
    required this.address,
    required this.type,
    required bool isConnected,
    required BluetoothPrinter printer,
  })  : _plugin = printer,
        _isConnected = isConnected;

  Future<bool> connect() async {
    _isConnected = await _plugin._connect(this);
    return _isConnected;
  }

  bool get isConnected => _isConnected;
  Future<void> disconnect() async {
    _isConnected = false;
    return _plugin._channel.invokeMethod('disconnect');
  }

  Future<dynamic> printBytes({
    required Uint8List bytes,
    void Function(int total, int progress)? progress,
  }) async {
    final completer = Completer<bool>();
    StreamSubscription? listener;
    listener = _plugin._printingProgress.stream.listen((event) {
      final int t = event['total'];
      final int p = event['progress'];
      if (progress != null) {
        progress(t, p);
      }

      if (t == p) {
        listener?.cancel();
        if (!completer.isCompleted) {
          completer.complete(true);
        }
      }
    });

    var result = await _plugin._channel.invokeMethod(
      'print',
      bytes,
    );
    print("printBytes result: $result");

    // await completer.future;
    return result;
  }

  Future<void> printImage({
    required img.Image image,
    PaperSize paperSize = PaperSize.mm58,
    void Function(int total, int progress)? progress,
  }) async {
    img.Image src;

    final dotsPerLine = paperSize.width;

    // make sure image not bigger than printable area
    if (image.width > dotsPerLine) {
      double ratio = dotsPerLine / image.width;
      int height = (image.height * ratio).ceil();
      src = img.copyResize(
        image,
        width: dotsPerLine,
        height: height,
      );
    } else {
      src = image;
    }

    final profile = await CapabilityProfile.load();
    final generator = Generator(paperSize, profile);
    final data = generator.image(src);

    await printBytes(
      bytes: Uint8List.fromList(data),
      progress: progress,
    );
  }
}
