"""Modelos de entrada y salida (generan el contrato OpenAPI en /docs)."""
from datetime import datetime
from typing import Literal

from pydantic import BaseModel, Field, field_validator


class RegistroEntrada(BaseModel):
    nombre_visible: str = Field(min_length=2, max_length=100)
    correo: str = Field(min_length=5, max_length=254)
    clave: str = Field(min_length=8, max_length=128)

    @field_validator("correo")
    @classmethod
    def correo_valido(cls, v: str) -> str:
        v = v.strip()
        if "@" not in v or v.startswith("@") or v.endswith("@"):
            raise ValueError("correo inválido")
        return v


class CuentaSalida(BaseModel):
    id_usuario: int
    nombre_visible: str
    estado: str
    roles: list[str]


class SesionEntrada(BaseModel):
    correo: str
    clave: str


class SesionSalida(BaseModel):
    token: str
    vence_en: datetime


class RecuperacionEntrada(BaseModel):
    correo: str


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
