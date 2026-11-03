import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../data/app_data.dart';
import '../services/auth_session.dart';

class ProfileAvatar extends StatelessWidget {
  final double size;
  final bool camera;
  const ProfileAvatar({super.key, this.size = 52, this.camera = false});

  @override
  Widget build(BuildContext context) {
    final session = AuthSession.instance;
    return AnimatedBuilder(
      animation: Listenable.merge([
        session.profileChanges,
        session.sessionChanges,
        session.avatarBusy,
      ]),
      builder: (context, _) {
        final user = currentUser;
        final busy = session.avatarBusy.value;
        return SizedBox(
          width: size,
          height: size,
          child: Stack(clipBehavior: Clip.none, children: [
            Semantics(
              button: true,
              label: 'Lihat foto profil',
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: user == null || busy
                    ? null
                    : () => showAvatarPreview(context),
                child: AvatarImage(
                    key: ValueKey(
                        '${session.sessionGeneration}:${user?.id}:${user?.avatarVersion}'),
                    size: size),
              ),
            ),
            if (camera)
              Positioned(
                right: -10,
                bottom: -10,
                child: IconButton(
                  tooltip: 'Ganti Foto Profil',
                  onPressed: user == null || busy
                      ? null
                      : () => changeProfilePhoto(context),
                  icon: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                        color: const Color(0xFF1976D2),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2)),
                    child: const Icon(Icons.camera_alt_outlined,
                        size: 14, color: Colors.white),
                  ),
                ),
              ),
            if (busy)
              Positioned.fill(child: CircularProgressIndicator(strokeWidth: 2)),
          ]),
        );
      },
    );
  }
}

class AvatarImage extends StatelessWidget {
  final double size;
  const AvatarImage({super.key, required this.size});

  @override
  Widget build(BuildContext context) {
    final user = currentUser;
    final initials = (user?.namaLengkap ?? '')
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part.characters.first.toUpperCase())
        .join();
    final fallback = CircleAvatar(
      radius: size / 2,
      backgroundColor: const Color(0xFF1976D2),
      child: initials.isEmpty
          ? Icon(Icons.person_outline, color: Colors.white, size: size * .45)
          : Text(initials,
              style: TextStyle(
                  fontSize: size * .32,
                  color: Colors.white,
                  fontWeight: FontWeight.w800)),
    );
    if (user?.avatarUrl == null) return fallback;
    return FutureBuilder<Uint8List>(
      key: ValueKey(
          '${AuthSession.instance.sessionGeneration}:${user?.id}:${user?.avatarVersion}'),
      future: AuthSession.instance.avatarBytes(),
      builder: (context, snapshot) => snapshot.hasData
          ? ClipOval(
              child: Image.memory(snapshot.data!,
                  width: size,
                  height: size,
                  fit: BoxFit.cover,
                  gaplessPlayback: false,
                  errorBuilder: (_, __, ___) => fallback))
          : fallback,
    );
  }
}

Future<void> showAvatarPreview(BuildContext context) async {
  final owner = currentUser?.id;
  final session = AuthSession.instance;
  final generation = session.sessionGeneration;
  if (owner == null || session.avatarBusy.value) return;
  final navigator = Navigator.of(context, rootNavigator: true);
  final avatarBox = context.findRenderObject() as RenderBox;
  final overlayBox = navigator.overlay!.context.findRenderObject() as RenderBox;
  final sourceRect =
      avatarBox.localToGlobal(Offset.zero, ancestor: overlayBox) &
          avatarBox.size;
  final reduceMotion = MediaQuery.disableAnimationsOf(context);
  final themes = InheritedTheme.capture(from: context, to: navigator.context);
  final changePhoto = await showGeneralDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.transparent,
    transitionDuration:
        reduceMotion ? Duration.zero : const Duration(milliseconds: 350),
    transitionBuilder: (_, __, ___, child) => child,
    pageBuilder: (dialogContext, animation, _) => themes.wrap(
      AnimatedBuilder(
        animation: Listenable.merge([
          session.profileChanges,
          session.sessionChanges,
          session.avatarBusy,
        ]),
        builder: (context, _) {
          final valid = session.isCurrentGeneration(generation) &&
              currentUser?.id == owner;
          final colors = Theme.of(context).colorScheme;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.pop(dialogContext),
            child: LayoutBuilder(builder: (context, constraints) {
              final size = math.min(
                  320.0, math.max(0.0, constraints.biggest.shortestSide - 64));
              final targetRect = Rect.fromCenter(
                  center: constraints.biggest.center(Offset.zero),
                  width: size,
                  height: size);
              return Stack(children: [
                Positioned.fill(
                  child: FadeTransition(
                    opacity: reduceMotion
                        ? const AlwaysStoppedAnimation(1.0)
                        : animation
                            .drive(CurveTween(curve: Curves.easeInOutCubic)),
                    child: ClipRect(
                      child: BackdropFilter(
                        filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                        child: ColoredBox(
                            color: colors.surface.withValues(alpha: .48)),
                      ),
                    ),
                  ),
                ),
                AnimatedBuilder(
                  animation: animation,
                  child: SizedBox.square(
                    dimension: size,
                    child: Stack(clipBehavior: Clip.none, children: [
                      if (valid)
                        Semantics(
                          image: true,
                          label: 'Foto Profil',
                          child: ClipOval(
                            child: GestureDetector(
                              onTap: () {},
                              child: AvatarImage(
                                key: ValueKey(
                                    '$generation:$owner:${currentUser?.avatarVersion}'),
                                size: size,
                              ),
                            ),
                          ),
                        )
                      else
                        Center(
                          child: Material(
                            color: Colors.transparent,
                            child: Text('Sesi telah berakhir.',
                                style: TextStyle(color: colors.onSurface)),
                          ),
                        ),
                      Positioned(
                        right: size * .06,
                        bottom: size * .06,
                        child: IconButton.filled(
                          tooltip: 'Ganti Foto Profil',
                          onPressed: valid && !session.avatarBusy.value
                              ? () => Navigator.pop(dialogContext, true)
                              : null,
                          icon: const Icon(Icons.edit_outlined),
                        ),
                      ),
                    ]),
                  ),
                  builder: (context, child) {
                    final progress = reduceMotion
                        ? 1.0
                        : Curves.easeInOutCubic.transform(animation.value);
                    return Positioned.fromRect(
                      rect: Rect.lerp(sourceRect, targetRect, progress)!,
                      child: FittedBox(child: child),
                    );
                  },
                ),
              ]);
            }),
          );
        },
      ),
    ),
  );
  if (changePhoto == true &&
      context.mounted &&
      session.isCurrentGeneration(generation) &&
      currentUser?.id == owner) {
    await changeProfilePhoto(context);
  }
}

bool _photoFlowActive = false;
Future<void> changeProfilePhoto(BuildContext context) async {
  final session = AuthSession.instance;
  if (_photoFlowActive || session.avatarBusy.value || currentUser == null)
    return;
  final generation = session.sessionGeneration;
  final owner = currentUser!.id;
  bool valid() =>
      session.isCurrentGeneration(generation) && currentUser?.id == owner;
  _photoFlowActive = true;
  try {
    final user = currentUser!;
    final action = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      builder: (context) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const ListTile(
                title: Text('Foto Profil',
                    style: TextStyle(fontWeight: FontWeight.w800))),
            for (final item in [
              ('gallery', Icons.photo_library_outlined, 'Pilih dari Galeri'),
              ('camera', Icons.camera_alt_outlined, 'Ambil dengan Kamera'),
              if (user.googleAvatarAvailable && user.avatarSource != 'google')
                ('google', Icons.restore, 'Kembalikan Foto Google'),
              ('default', Icons.person_outline, 'Gunakan Avatar Default'),
            ])
              ListTile(
                  leading: Icon(item.$2),
                  title: Text(item.$3),
                  onTap: () => Navigator.pop(context, item.$1)),
          ])),
    );
    if (action == null || !context.mounted || !valid()) return;
    if (action == 'gallery' || action == 'camera') {
      final file = await ImagePicker().pickImage(
        source: action == 'gallery' ? ImageSource.gallery : ImageSource.camera,
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 95,
      );
      if (file == null || !context.mounted || !valid()) return;
      if (await file.length() > 5 * 1024 * 1024) {
        throw const ApiException('Ukuran foto maksimal 5 MiB.');
      }
      final input = await file.readAsBytes();
      if (!context.mounted || !valid()) return;
      final cropped = await Navigator.of(context).push<Uint8List>(
          MaterialPageRoute(builder: (_) => AvatarCropScreen(bytes: input)));
      if (cropped == null || !context.mounted || !valid()) return;
      await session.changeAvatar(bytes: cropped);
    } else {
      await session.changeAvatar(source: action);
    }
    if (context.mounted && valid()) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Foto profil berhasil diperbarui.')));
    }
  } catch (error) {
    if (context.mounted && valid()) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(error is ApiException
              ? error.message
              : 'Foto belum dapat diproses. Periksa izin kamera/galeri dan coba lagi.')));
    }
  } finally {
    _photoFlowActive = false;
  }
}

class AvatarCropScreen extends StatefulWidget {
  final Uint8List bytes;
  const AvatarCropScreen({required this.bytes});
  @override
  State<AvatarCropScreen> createState() => _AvatarCropScreenState();
}

class _AvatarCropScreenState extends State<AvatarCropScreen> {
  final _transform = TransformationController();
  ui.Image? _image;
  String? _error;
  bool _saving = false;
  double _side = 0;
  double _minScale = 1;

  @override
  void initState() {
    super.initState();
    _decode();
  }

  Future<void> _decode() async {
    ui.Codec? codec;
    try {
      final buffer = await ui.ImmutableBuffer.fromUint8List(widget.bytes);
      final descriptor = await ui.ImageDescriptor.encoded(buffer);
      try {
        if (descriptor.width > 8192 ||
            descriptor.height > 8192 ||
            descriptor.width * descriptor.height > 32000000) {
          throw const FormatException('Dimensi foto terlalu besar.');
        }
        codec = await descriptor.instantiateCodec(
            targetWidth: descriptor.width > 2048 ? 2048 : null);
        final image = (await codec.getNextFrame()).image;
        if (!mounted) {
          image.dispose();
          return;
        }
        setState(() => _image = image);
      } finally {
        descriptor.dispose();
        buffer.dispose();
      }
    } catch (_) {
      if (mounted)
        setState(() => _error =
            'Foto tidak dapat dibuka. Pilih JPG, PNG, atau WebP yang valid.');
    } finally {
      codec?.dispose();
    }
  }

  Future<void> _confirm() async {
    if (_saving || _image == null || _side == 0) return;
    setState(() => _saving = true);
    ui.Image? output;
    try {
      final origin = _transform.toScene(Offset.zero);
      final cropSide = (_side / _transform.value.entry(0, 0))
          .clamp(1.0, math.min(_image!.width, _image!.height).toDouble());
      final source = Rect.fromLTWH(
        origin.dx.clamp(0.0, _image!.width - cropSide),
        origin.dy.clamp(0.0, _image!.height - cropSide),
        cropSide,
        cropSide,
      );
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.drawImageRect(_image!, source, const Rect.fromLTWH(0, 0, 512, 512),
          Paint()..filterQuality = FilterQuality.high);
      final picture = recorder.endRecording();
      try {
        output = await picture.toImage(512, 512);
      } finally {
        picture.dispose();
      }
      final bytes = await output.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) throw const FormatException();
      if (mounted) Navigator.pop(context, bytes.buffer.asUint8List());
    } catch (_) {
      if (mounted)
        setState(() {
          _saving = false;
          _error = 'Foto belum dapat dipotong. Coba lagi.';
        });
    } finally {
      output?.dispose();
    }
  }

  @override
  void dispose() {
    _transform.dispose();
    _image?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: !_saving,
        child: Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
              title: const Text('Potong Foto'),
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              leading: IconButton(
                  tooltip: 'Batal',
                  onPressed: _saving ? null : () => Navigator.pop(context),
                  icon: const Icon(Icons.close))),
          body: SafeArea(
              child: Column(children: [
            const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Geser dan cubit untuk menyesuaikan foto',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white))),
            Expanded(
                child: Center(
                    child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: LayoutBuilder(builder: (context, constraints) {
                          final image = _image;
                          if (image == null)
                            return _error == null
                                ? const CircularProgressIndicator()
                                : const SizedBox.shrink();
                          final side = math.min(
                              constraints.maxWidth, constraints.maxHeight);
                          if (_side != side) {
                            _side = side;
                            _minScale = math.max(
                                side / image.width, side / image.height);
                            _transform.value = Matrix4.identity()
                              ..translateByDouble(
                                  (side - image.width * _minScale) / 2,
                                  (side - image.height * _minScale) / 2,
                                  0,
                                  1)
                              // InteractiveViewer includes Z when measuring scale; keep all axes equal.
                              ..scaleByDouble(
                                  _minScale, _minScale, _minScale, 1);
                          }
                          return SizedBox.square(
                              dimension: side,
                              child: Stack(children: [
                                ClipRect(
                                    child: InteractiveViewer(
                                  transformationController: _transform,
                                  constrained: false,
                                  minScale: _minScale,
                                  maxScale: _minScale * 5,
                                  panEnabled: !_saving,
                                  scaleEnabled: !_saving,
                                  child: RawImage(
                                      image: image,
                                      width: image.width.toDouble(),
                                      height: image.height.toDouble(),
                                      fit: BoxFit.fill,
                                      alignment: Alignment.topLeft),
                                )),
                                const Positioned.fill(
                                    child: IgnorePointer(
                                        child: CustomPaint(
                                            painter: _AvatarCropOverlay()))),
                              ]));
                        })))),
            if (_error != null)
              Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(_error!,
                      style: const TextStyle(color: Colors.white))),
            Padding(
                padding: const EdgeInsets.all(20),
                child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                        onPressed: _image == null || _saving ? null : _confirm,
                        child: _saving
                            ? const SizedBox.square(
                                dimension: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2))
                            : const Text('Gunakan Foto')))),
          ])),
        ),
      );
}

class _AvatarCropOverlay extends CustomPainter {
  const _AvatarCropOverlay();

  @override
  void paint(Canvas canvas, Size size) {
    final circle = Rect.fromLTWH(0, 0, size.width, size.height);
    final outside = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addOval(circle);
    canvas.drawPath(
        outside, Paint()..color = Colors.black.withValues(alpha: .65));
    canvas.drawOval(
        circle,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2);
  }

  @override
  bool shouldRepaint(covariant _AvatarCropOverlay oldDelegate) => false;
}
