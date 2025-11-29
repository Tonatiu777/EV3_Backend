# main.py - FastAPI EV3_BD
from fastapi import FastAPI, Depends, HTTPException, UploadFile, File, Form
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles

from sqlalchemy import (
    create_engine,
    Column,
    Integer,
    String,
    TIMESTAMP,
    DECIMAL,
    ForeignKey,
    func
)
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker, relationship

from pydantic import BaseModel
from typing import List, Optional
from datetime import datetime
import hashlib
import os
import shutil
import requests

# -----------------------------------
# CONFIGURACIÓN BD
# -----------------------------------
DATABASE_URL = "mysql+pymysql://root:semes8selap@localhost:3306/EV3_BD"

engine = create_engine(DATABASE_URL, pool_pre_ping=True)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()

# -----------------------------------
# MODELOS BD (SQLAlchemy)
# -----------------------------------
class User(Base):
    __tablename__ = "P9_users"
    user_id = Column(Integer, primary_key=True, index=True)
    username = Column(String(50), unique=True, nullable=False)
    password_hash = Column(String(255), nullable=False)
    full_name = Column(String(100))
    created_at = Column(TIMESTAMP, server_default=func.now())

    packages = relationship("Package", back_populates="user")
    deliveries = relationship("Delivery", back_populates="user")


class Package(Base):
    __tablename__ = "P9_packages"
    package_id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("P9_users.user_id"), nullable=False)
    tracking_code = Column(String(50), nullable=False)
    destino = Column(String(255), nullable=False)
    estatus = Column(String(20), default="pendiente")
    created_at = Column(TIMESTAMP, server_default=func.now())

    user = relationship("User", back_populates="packages")
    deliveries = relationship("Delivery", back_populates="package")


class Delivery(Base):
    __tablename__ = "P9_deliveries"
    delivery_id = Column(Integer, primary_key=True, index=True)
    package_id = Column(Integer, ForeignKey("P9_packages.package_id"), nullable=False)
    user_id = Column(Integer, ForeignKey("P9_users.user_id"), nullable=False)
    ruta_foto = Column(String(255), nullable=False)
    latitude = Column(DECIMAL(10, 8), nullable=False)
    longitude = Column(DECIMAL(11, 8), nullable=False)
    address = Column(String(255))
    delivered_at = Column(TIMESTAMP, server_default=func.now())

    user = relationship("User", back_populates="deliveries")
    package = relationship("Package", back_populates="deliveries")


class Foto(Base):
    __tablename__ = "P10_foto"
    id = Column(Integer, primary_key=True, index=True)
    descripcion = Column(String(255), nullable=False)
    ruta_foto = Column(String(255), nullable=False)
    fecha = Column(TIMESTAMP, server_default=func.now())


Base.metadata.create_all(bind=engine)

# -----------------------------------
# USUARIO DEFAULT
# -----------------------------------
def hash_password(password: str) -> str:
    return hashlib.md5(password.encode("utf-8")).hexdigest()

def create_default_user():
    db = SessionLocal()
    try:
        existing = db.query(User).filter(User.username == "admin").first()
        if not existing:
            default_pass = hash_password("admin123")
            user = User(
                username="admin",
                password_hash=default_pass,
                full_name="Administrador del sistema",
            )
            db.add(user)
            db.commit()
            print(">>> Usuario default creado: admin / admin123")
        else:
            print(">>> Usuario default ya existe")
    finally:
        db.close()

create_default_user()

# -----------------------------------
# MODELOS Pydantic
# -----------------------------------
class UserCreate(BaseModel):
    username: str
    password: str
    full_name: Optional[str] = None


class UserLogin(BaseModel):
    username: str
    password: str


class UserOut(BaseModel):
    user_id: int
    username: str
    full_name: Optional[str]

    class Config:
        from_attributes = True


class PackageOut(BaseModel):
    package_id: int
    tracking_code: str
    destino: str
    estatus: str

    class Config:
        from_attributes = True


class DeliveryOut(BaseModel):
    delivery_id: int
    package_id: int
    user_id: int
    ruta_foto: str
    latitude: float
    longitude: float
    address: Optional[str]
    delivered_at: datetime

    class Config:
        from_attributes = True


# -----------------------------------
# DEPENDENCIA DB
# -----------------------------------
def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


# -----------------------------------
# CONFIGURACIÓN FASTAPI
# -----------------------------------
app = FastAPI(title="EV3 Paquexpress API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

os.makedirs("uploads", exist_ok=True)
app.mount("/uploads", StaticFiles(directory="uploads"), name="uploads")

# -----------------------------------
# ENDPOINTS DE AUTENTICACIÓN
# -----------------------------------
@app.post("/register", response_model=UserOut)
def register(user: UserCreate, db=Depends(get_db)):
    existing = db.query(User).filter(User.username == user.username).first()
    if existing:
        raise HTTPException(status_code=400, detail="El usuario ya existe")

    hashed = hash_password(user.password)
    new_user = User(
        username=user.username,
        password_hash=hashed,
        full_name=user.full_name,
    )
    db.add(new_user)
    db.commit()
    db.refresh(new_user)
    return new_user


@app.post("/login", response_model=UserOut)
def login(creds: UserLogin, db=Depends(get_db)):
    hashed = hash_password(creds.password)
    user = (
        db.query(User)
        .filter(User.username == creds.username, User.password_hash == hashed)
        .first()
    )
    if not user:
        raise HTTPException(status_code=401, detail="Credenciales inválidas")
    return user


# -----------------------------------
# ENDPOINTS DE PAQUETES
# -----------------------------------
@app.get("/packages/{user_id}", response_model=List[PackageOut])
def get_packages(user_id: int, db=Depends(get_db)):
    paquetes = db.query(Package).filter(Package.user_id == user_id).all()
    return paquetes


@app.post("/packages/demo_create")
def create_demo_packages(user_id: int = Form(...), db=Depends(get_db)):
    demo = [
        Package(user_id=user_id, tracking_code="PKG-001", destino="Calle 1 #123, Centro"),
        Package(user_id=user_id, tracking_code="PKG-002", destino="Av. 2 #456, Norte"),
    ]
    db.add_all(demo)
    db.commit()
    return {"msg": "Paquetes demo creados"}


# -----------------------------------
# ENTREGAR PAQUETE (GPS + FOTO)
# -----------------------------------
@app.post("/deliveries/", response_model=DeliveryOut)
async def entregar_paquete(
    user_id: int = Form(...),
    package_id: int = Form(...),
    latitude: float = Form(...),
    longitude: float = Form(...),
    file: UploadFile = File(...),
    db=Depends(get_db),
):
    user = db.query(User).filter(User.user_id == user_id).first()
    if not user:
        raise HTTPException(status_code=400, detail=f"Usuario {user_id} no existe")

    package = db.query(Package).filter(Package.package_id == package_id).first()
    if not package:
        raise HTTPException(status_code=400, detail=f"Paquete {package_id} no existe")

    filename = f"{datetime.utcnow().timestamp()}_{file.filename}"
    ruta = os.path.join("uploads", filename)

    with open(ruta, "wb") as buffer:
        shutil.copyfileobj(file.file, buffer)

    foto = Foto(descripcion=f"Evidencia paquete {package.tracking_code}", ruta_foto=ruta)
    db.add(foto)

    address = "Dirección no disponible"
    try:
        url = (
            "https://nominatim.openstreetmap.org/reverse"
            f"?format=json&lat={latitude}&lon={longitude}"
        )
        headers = {"User-Agent": "EV3Paquexpress/1.0"}
        r = requests.get(url, headers=headers, timeout=5)
        if r.status_code == 200:
            address = r.json().get("display_name", address)
    except:
        pass

    delivery = Delivery(
        package_id=package_id,
        user_id=user_id,
        ruta_foto=ruta,
        latitude=latitude,
        longitude=longitude,
        address=address[:255],
    )
    db.add(delivery)

    package.estatus = "entregado"

    db.commit()
    db.refresh(delivery)
    return delivery


# -----------------------------------
# HISTORIAL DE ENTREGAS
# -----------------------------------
@app.get("/deliveries/user/{user_id}", response_model=List[DeliveryOut])
def deliveries_by_user(user_id: int, db=Depends(get_db)):
    deliveries = (
        db.query(Delivery)
        .filter(Delivery.user_id == user_id)
        .order_by(Delivery.delivered_at.desc())
        .all()
    )
    return deliveries
