import base64
import binascii
import io

from PIL import Image, ImageOps, UnidentifiedImageError


def limpiar_imagen(contenido, lado_maximo=2000):
    """Devuelve JPEG sin metadatos o lanza ValueError si supera los límites."""
    try:
        raw = base64.b64decode(contenido, validate=True)
        if len(raw) > 2097152:
            raise ValueError()
        with Image.open(io.BytesIO(raw)) as original:
            if original.format not in ('JPEG', 'PNG', 'WEBP') or original.width * original.height > 16000000:
                raise ValueError()
            imagen = ImageOps.exif_transpose(original).convert('RGB')
            imagen.thumbnail((lado_maximo, lado_maximo))
            imagen.info.clear()
            salida = io.BytesIO()
            imagen.save(salida, format='JPEG', quality=88)
        resultado = salida.getvalue()
        if not 0 < len(resultado) <= 2097152:
            raise ValueError()
        return resultado
    except (ValueError, binascii.Error, UnidentifiedImageError, OSError, Image.DecompressionBombError):
        raise ValueError('Formato o tamaño de imagen inválido.') from None
