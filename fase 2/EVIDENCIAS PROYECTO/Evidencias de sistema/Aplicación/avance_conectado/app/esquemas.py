"""Modelos de entrada y salida (generan el contrato OpenAPI en /docs)."""
from datetime import datetime
from typing import Literal
import re

from pydantic import BaseModel, Field, field_validator


class RegistroEntrada(BaseModel):
    modalidad_ciudadana: Literal['colaborador','con_vehiculo'] = 'colaborador'
    nombre_visible: str = Field(min_length=2, max_length=100)
    correo: str = Field(min_length=5, max_length=254)
    clave: str = Field(min_length=8, max_length=128)

    @field_validator("correo")
    @classmethod
    def correo_valido(cls, v: str) -> str:
        v = v.strip()
        if not re.fullmatch(r"[^\s@<>\x00-\x1f]+@[^\s@<>.]+(?:\.[^\s@<>.]+)+",v):
            raise ValueError("correo inválido")
        return v

    @field_validator("nombre_visible", mode="before")
    @classmethod
    def limpiar_nombre(cls,v):
        return ' '.join(v.split()) if isinstance(v,str) else v


class CuentaSalida(BaseModel):
    id_usuario: int
    nombre_visible: str
    estado: str
    roles: list[str]


class SesionEntrada(BaseModel):
    correo: str = Field(min_length=5,max_length=254)
    clave: str = Field(min_length=1,max_length=128)


class SesionSalida(BaseModel):
    token: str | None = None
    vence_en: datetime | None = None
    requiere_mfa: bool = False
    id_desafio: str | None = None


class RecuperacionEntrada(BaseModel):
    correo: str = Field(min_length=5,max_length=254)


class RecuperacionSalida(BaseModel):
    mensaje: str
    token_prueba: str | None = None


class RecuperacionConfirmar(BaseModel):
    token: str
    nueva_clave: str = Field(min_length=8, max_length=128)


class CasoEntrada(BaseModel):
    id_vehiculo: int
    id_organizacion: int | None = None
    fecha_hecho: datetime
    zona: str = Field(min_length=2, max_length=200)
    descripcion: str = Field(min_length=5, max_length=4000)
    latitud: float = Field(ge=-90, le=90)
    longitud: float = Field(ge=-180, le=180)
    precision_m: float | None = Field(default=None, ge=0)
    tipo_incidente: Literal["encerrona", "portonazo", "robo_estacionado", "otro", "sin_clasificar"] = "sin_clasificar"


class CasoSalida(BaseModel):
    id_caso: int
    folio: str
    estado: str
    recibido_en: datetime
    reintento: bool = False


class BandejaItem(BaseModel):
    id_caso: int
    id_organizacion: int
    folio: str
    estado: str
    prioridad: str
    creado_en: datetime
    aportes_pendientes: int
    primera_revision_en: datetime | None = None
