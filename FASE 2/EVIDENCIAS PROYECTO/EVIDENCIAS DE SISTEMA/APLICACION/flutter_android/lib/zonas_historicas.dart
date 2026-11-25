import 'package:flutter/material.dart';

const zonaModerada = Color(0xffff9b42);
const zonaAlta = Color(0xffff465d);

bool concentracionAlta(Map zona) =>
    zona['nivel'] == 'alta' ||
    (zona['nivel'] == null && ((zona['antecedentes'] as num?) ?? 0) >= 4);

class LeyendaZonas extends StatelessWidget {
  const LeyendaZonas({super.key});

  @override
  Widget build(BuildContext context) => const Wrap(
    spacing: 16,
    runSpacing: 6,
    children: [
      _Nivel(zonaModerada, '2–3 antecedentes'),
      _Nivel(zonaAlta, '4 o más antecedentes'),
    ],
  );
}

class _Nivel extends StatelessWidget {
  final Color color;
  final String texto;
  const _Nivel(this.color, this.texto);

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(Icons.circle, color: color, size: 10),
      const SizedBox(width: 6),
      Text(texto, style: Theme.of(context).textTheme.labelMedium),
    ],
  );
}
