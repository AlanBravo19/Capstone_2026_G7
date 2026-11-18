import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import 'api.dart';
import 'foto_aporte.dart';
import 'ui.dart';

const publicPhotoConsentText =
    'Autorizo mostrar esta foto del vehículo en Colaborar';
const publicPhotoReviewText =
    'El operador debe revisar y seleccionar la foto antes de publicarla. Evita rostros, documentos y datos personales. Puedes retirar la autorización desde Seguimiento.';

class CasePhotoUpload extends StatefulWidget {
  final RutaApi api;
  final int cid;
  final bool collaborationRequested;
  const CasePhotoUpload({
    super.key,
    required this.api,
    required this.cid,
    required this.collaborationRequested,
  });

  @override
  State<CasePhotoUpload> createState() => _CasePhotoUploadState();
}

class _CasePhotoUploadState extends State<CasePhotoUpload> {
  Uint8List? photo;
  bool authorized = false, busy = false;
  String? _signature, _key;

  Future<void> save() async {
    if (busy || photo == null) return;
    setState(() => busy = true);
    try {
      final body = {
        'contenido_base64': base64Encode(photo!),
        'autorizar_foto_publica': widget.collaborationRequested && authorized,
      };
      final signature = jsonEncode(body);
      if (_signature != signature) {
        _signature = signature;
        _key = const Uuid().v4();
      }
      await widget.api.request('/casos/${widget.cid}/fotos', method: 'POST',
          body: {...body, 'clave_envio': _key});
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) feedback(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Adjuntar foto al caso'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('La foto se guarda como evidencia privada.'),
          FotoAporte(
            foto: photo,
            ocupado: busy,
            cambiar: (value) => setState(() {
              photo = value;
              authorized = false;
            }),
          ),
          if (photo != null && widget.collaborationRequested)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: authorized,
              onChanged: busy ? null : (v) => setState(() => authorized = v == true),
              title: const Text(publicPhotoConsentText),
              subtitle: const Text(publicPhotoReviewText),
            ),
          if (!widget.collaborationRequested)
            const Note('Para mostrar una foto en Colaborar, solicita primero colaboración ciudadana. Después podrás autorizarla desde Seguimiento.'),
        ],
      ),
    ),
    actions: [
      TextButton(onPressed: busy ? null : () => Navigator.pop(context), child: const Text('Cancelar')),
      FilledButton(
        onPressed: busy || photo == null ? null : save,
        child: Text(busy ? 'Guardando…' : 'Guardar foto'),
      ),
    ],
  );
}

/// Existing evidence remains private until a separate, explicit grant and review.
class PhotoPublicationControl extends StatefulWidget {
  final RutaApi api;
  final int cid, eid;
  final bool authorized, canGrant;
  final VoidCallback onChanged;
  const PhotoPublicationControl({
    super.key,
    required this.api,
    required this.cid,
    required this.eid,
    required this.authorized,
    required this.canGrant,
    required this.onChanged,
  });

  @override
  State<PhotoPublicationControl> createState() => _PhotoPublicationControlState();
}

class _PhotoPublicationControlState extends State<PhotoPublicationControl> {
  bool busy = false;

  Future<void> change() async {
    if (busy) return;
    final grant = !widget.authorized;
    setState(() => busy = true);
    try {
      if (grant) {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (_) => const _PhotoGrantDialog(),
        );
        if (confirmed != true) return;
      }
      await widget.api.request(
        '/mis-casos/${widget.cid}/fotos/${widget.eid}/publicacion',
        method: 'POST', body: {'autorizada': grant},
      );
      if (!mounted) return;
      feedback(context, grant
          ? 'Foto autorizada. El operador debe revisarla y seleccionarla antes de publicarla.'
          : 'Autorización retirada. La foto ya no está disponible en Colaborar.');
      widget.onChanged();
    } catch (e) {
      if (mounted) feedback(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(widget.authorized
          ? 'Autorizada para revisión y selección pública'
          : 'Sin autorización para publicación'),
      if (!widget.authorized && !widget.canGrant)
        const Text('Solicita colaboración en un caso abierto para autorizar esta foto.'),
      TextButton.icon(
        onPressed: busy || (!widget.authorized && !widget.canGrant) ? null : change,
        icon: Icon(widget.authorized ? Icons.hide_image_outlined : Icons.add_photo_alternate_outlined),
        label: Text(busy ? 'Guardando…' : widget.authorized
            ? 'Retirar autorización pública' : 'Autorizar foto en Colaborar'),
      ),
    ],
  );
}

class _PhotoGrantDialog extends StatefulWidget {
  const _PhotoGrantDialog();
  @override
  State<_PhotoGrantDialog> createState() => _PhotoGrantDialogState();
}

class _PhotoGrantDialogState extends State<_PhotoGrantDialog> {
  bool consent = false;
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Autorizar esta foto'),
    content: SingleChildScrollView(
      child: CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        value: consent,
        onChanged: (v) => setState(() => consent = v == true),
        title: const Text(publicPhotoConsentText),
        subtitle: const Text(publicPhotoReviewText),
      ),
    ),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
      FilledButton(onPressed: consent ? () => Navigator.pop(context, true) : null, child: const Text('Autorizar para revisión')),
    ],
  );
}
