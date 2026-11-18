"""Genera el catálogo a partir de liv2026.xlsx y pes2026.xlsx publicados por el SII.
Uso: python importar_catalogo_sii.py carpeta_con_los_archivos
Fuente: https://www.sii.cl/servicios_online/1049-2612.html
"""
import json
import sys
from pathlib import Path
from collections import defaultdict
from openpyxl import load_workbook

tipos = {
    'Sedán': 'automovil', 'Hatchback': 'automovil', 'Suv': 'automovil',
    'Coupé': 'automovil', 'Cabriolet': 'automovil', 'Camioneta': 'camioneta',
    'Moto': 'motocicleta', 'Furgón': 'furgon', 'Furgón carga general': 'furgon',
    'Camión': 'camion', 'Tracto Camión': 'camion',
}
catalogo = defaultdict(lambda: defaultdict(set))
for archivo in ('liv2026.xlsx', 'pes2026.xlsx'):
    libro = load_workbook(Path(sys.argv[1]) / archivo, read_only=True, data_only=True)
    for fila in libro.worksheets[0].values:
        categoria = tipos.get(fila[2])
        if not categoria or fila[3] is None or fila[4] is None:
            continue
        marca, modelo = (' '.join(str(v).upper().split()) for v in fila[3:5])
        if marca and modelo and marca != 'S/M':
            catalogo[categoria][marca].add(modelo)
    libro.close()
resultado = {tipo: {marca: sorted(modelos) for marca, modelos in marcas.items()} for tipo, marcas in catalogo.items()}
destino = Path(__file__).resolve().parents[1] / 'app' / 'catalogo_sii_2026.json'
destino.write_text(json.dumps(resultado, sort_keys=True, ensure_ascii=False, separators=(',', ':')), encoding='utf-8')
print({tipo: sum(map(len, marcas.values())) for tipo, marcas in resultado.items()})

