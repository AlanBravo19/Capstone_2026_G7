import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'movilidad.dart' show Mobility;

typedef ModelPhoto = ({String image, String source, String credit});

class ModelReference extends StatefulWidget {
  const ModelReference({
    super.key,
    required this.model,
    required this.fallback,
  });
  final String model;
  final Widget fallback;

  @override
  State<ModelReference> createState() => _ModelReferenceState();
}

class _ModelReferenceState extends State<ModelReference> {
  static final cache = <String, Future<ModelPhoto?>>{};
  static final headers = {
    'User-Agent':
        'RutaAlerta/0.27 (https://github.com/AlanBravo19/Capstone_2026_G7)',
  };

  static Future<List> pages(String host, Map<String, String> query) async {
    final uri = Uri.https(host, '/w/api.php', {
      'action': 'query',
      'format': 'json',
      'formatversion': '2',
      ...query,
    });
    final res = await http
        .get(uri, headers: headers)
        .timeout(const Duration(seconds: 8));
    if (res.statusCode != 200) throw const FormatException();
    return jsonDecode(utf8.decode(res.bodyBytes))['query']?['pages'] as List? ??
        [];
  }

  static String plain(String input) => input
      .replaceAll(RegExp(r'<[^>]*>'), '')
      .replaceAll('&amp;', '&')
      .replaceAll('&quot;', '"')
      .trim();

  static Future<ModelPhoto?> lookup(String model) async {
    try {
      final results = await pages('en.wikipedia.org', {
        'generator': 'search',
        'gsrsearch': 'intitle:"$model"',
        'gsrlimit': '5',
        'gsrnamespace': '0',
        'prop': 'pageimages',
        'pilicense': 'free',
        'piprop': 'name|thumbnail',
        'pithumbsize': '640',
      });
      for (final page in results) {
        if ((page['title'] as String).toLowerCase() != model.toLowerCase())
          continue;
        final file = page['pageimage'];
        final uri = Uri.tryParse(page['thumbnail']?['source'] as String? ?? '');
        if (file is! String ||
            uri == null ||
            uri.scheme != 'https' ||
            !{
              'upload.wikimedia.org',
              'thumb.wikimedia.org',
            }.contains(uri.host) ||
            !uri.path.contains('/commons/'))
          continue;
        final files = await pages('commons.wikimedia.org', {
          'titles': 'File:$file',
          'prop': 'imageinfo',
          'iiprop': 'extmetadata|url',
          'iiextmetadatafilter': 'Artist|LicenseShortName',
        });
        final info = (files.first['imageinfo'] as List).first;
        final source = Uri.parse(info['descriptionurl']);
        if (source.scheme != 'https' || source.host != 'commons.wikimedia.org')
          continue;
        final license = plain(info['extmetadata']['LicenseShortName']['value']);
        final artist = plain(info['extmetadata']['Artist']['value']);
        if (artist.isEmpty || license.isEmpty) continue;
        return (
          image: uri.toString(),
          source: source.toString(),
          credit: '$artist · $license',
        );
      }
    } catch (_) {
      cache.remove(model);
    }
    return null;
  }

  Future<ModelPhoto?> cached() {
    if (cache.length >= 160 && !cache.containsKey(widget.model))
      cache.remove(cache.keys.first);
    return cache.putIfAbsent(widget.model, () => lookup(widget.model));
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<ModelPhoto?>(
    future: cached(),
    builder: (context, snapshot) {
      final photo = snapshot.data;
      if (photo == null) return widget.fallback;
      return Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            photo.image,
            fit: BoxFit.contain,
            headers: headers,
            semanticLabel: 'Referencia de ${widget.model}',
            errorBuilder: (_, __, ___) => widget.fallback,
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Material(
              color: Colors.black87,
              child: InkWell(
                onTap: () async {
                  try {
                    await Mobility.source(photo.source);
                  } catch (_) {
                    if (context.mounted)
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('No se pudo abrir la fuente.'),
                        ),
                      );
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 5,
                    horizontal: 10,
                  ),
                  child: Text(
                    'Referencia del modelo · el color puede variar\n${photo.credit}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 11, color: Colors.white),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    },
  );
}
