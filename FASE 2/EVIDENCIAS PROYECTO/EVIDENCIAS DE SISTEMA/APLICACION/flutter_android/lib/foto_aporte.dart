import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'ui.dart';

class FotoAporte extends StatefulWidget {
  final Uint8List? foto;
  final bool ocupado;
  final ValueChanged<Uint8List?> cambiar;
  const FotoAporte({
    super.key,
    required this.foto,
    required this.ocupado,
    required this.cambiar,
  });
  @override
  State<FotoAporte> createState() => _FotoAporteState();
}

class _FotoAporteState extends State<FotoAporte> {
  bool eligiendo = false;
  Future<void> elegir(ImageSource origen) async {
    if (eligiendo || widget.ocupado) return;
    setState(() => eligiendo = true);
    try {
      final file = await ImagePicker().pickImage(
        source: origen,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 82,
      );
      if (file == null) return;
      if (await file.length() > 2097152) {
        throw Exception(
          'La imagen supera 2 MB. Selecciona una foto más pequeña.',
        );
      }
      final bytes = await file.readAsBytes();
      if (mounted && !widget.ocupado) widget.cambiar(bytes);
    } catch (e) {
      if (mounted) feedback(context, e);
    } finally {
      if (mounted) setState(() => eligiendo = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (widget.foto != null) ...[
        Image.memory(
          widget.foto!,
          height: 110,
          fit: BoxFit.contain,
          semanticLabel: 'Foto seleccionada',
        ),
        TextButton(
          onPressed: widget.ocupado ? null : () => widget.cambiar(null),
          child: const Text('Quitar foto'),
        ),
      ] else
        Wrap(
          spacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: widget.ocupado || eligiendo
                  ? null
                  : () => elegir(ImageSource.camera),
              icon: const Icon(Icons.photo_camera_outlined),
              label: const Text('Tomar foto'),
            ),
            TextButton.icon(
              onPressed: widget.ocupado || eligiendo
                  ? null
                  : () => elegir(ImageSource.gallery),
              icon: const Icon(Icons.photo_library_outlined),
              label: const Text('Elegir de galería'),
            ),
          ],
        ),
    ],
  );
}
