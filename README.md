# EV3_Backend
La empresa Paquexpress S.A. de C.V., dedicada a la logística y distribución de paquetes a nivel nacional, solicita el desarrollo de una aplicación móvil para sus agentes de entrega en campo. El objetivo es mejorar la trazabilidad y seguridad en el proceso de entrega de paquetes, especialmente en zonas urbanas y semiurbanas.
Paquexpress – Sistema de Entregas (EV3)

Aplicación móvil para agentes de entrega desarrollada en Flutter, comunicada con una API FastAPI, utilizando MySQL.
Permite gestionar paquetes, registrar entregas con fotografía, capturar ubicación GPS y visualizar mapas interactivos.

🚀 Tecnologías Utilizadas
Frontend – Flutter

Flutter / Dart

flutter_map

latlong2

camera

geolocator

http

Backend – FastAPI

FastAPI

Uvicorn

Python

JWT (sesiones)

passlib (hash de contraseñas)

mysql-connector-python

Base de Datos – MySQL

Tablas para usuarios, paquetes, entregas, fotos y asistencia

Integridad referencial

Script incluido en /database/EV3_BD.sql

📱 Funcionalidades de la Aplicación
✔ Inicio de sesión seguro

Validación de credenciales del agente

Contraseñas cifradas

Uso de JWT para sesiones

✔ Gestión de Paquetes

Lista de paquetes asignados al agente

Detalles por paquete (ID, destino, tracking code)

Estados: pendiente y entregado

✔ Registro de Entrega

Captura de foto como evidencia

Obtención de coordenadas GPS

Conversión de coordenadas a dirección (geocoding)

Guardado de foto, ubicación y estatus en la BD

✔ Mapa Interactivo

Visualización mediante flutter_map

OpenStreetMap (sin API Key)

Marcadores para destino o posición del agente

🗄️ Base de Datos EV3_BD

El repositorio contiene el script completo:

/database/EV3_BD.sql

Estructura de tablas principales:
Tabla	Descripción
P9_users	Usuarios/agentes
P9_attendance	Registro de asistencia
P9_packages	Paquetes asignados
P9_deliveries	Entregas con foto y GPS
P10_foto	Evidencias fotográficas
Usuario de prueba
Usuario: agente1
Contraseña: 1234
Hash MD5 almacenado

⚙️ Instalación del Backend (FastAPI)
1. Instalar dependencias
pip install fastapi uvicorn python-multipart passlib python-jose mysql-connector-python

2. Ejecutar API
uvicorn main:app --reload


Ruta base:

http://127.0.0.1:8000

📱 Instalación del Frontend (Flutter)
1. Descargar dependencias
flutter pub get

2. Paquetes requeridos
flutter pub add flutter_map
flutter pub add latlong2
flutter pub add geolocator
flutter pub add camera
flutter pub add http

3. Ejecutar la app
flutter run

🧭 Mapa Interactivo

El mapa usa OpenStreetMap vía:

flutter_map: any
latlong2: any


Ventajas:

Gratis

Sin tokens ni API Keys

Perfecto para entornos académicos

🔐 Seguridad de la API

Contraseñas cifradas con MD5/Passlib

Tokens JWT para autenticación

Validación de usuario por ID y rol

Protección de endpoints sensibles

📝 Endpoints Principales
Método	Endpoint	Descripción
POST	/login	Inicio de sesión
POST	/register	Crear nuevo agente
GET	/packages/{user_id}	Paquetes asignados
POST	/deliveries/	Entrega con foto y GPS
GET	/deliveries/user/{user_id}	Historial de entregas
📁 Estructura del Proyecto
EV3_Paquexpress/
│
├── api_fastapi/
│   ├── main.py
│   ├── database.py
│   └── utils/
│
├── flutter_app/
│   ├── lib/
│   │   ├── login_page.dart
│   │   ├── home_page.dart
│   │   ├── package_detail.dart
│   │   ├── delivery_page.dart
│   │   ├── map_page.dart
│   │   └── services/api_service.dart
│   └── pubspec.yaml
│
└── database/
    └── EV3_BD.sql

👥 Autores

Proyecto académico desarrollado por estudiantes de la
Universidad Tecnológica de Querétaro – DTAI

Fernando García Larruz

Citlali Vite Merino

Emilio Antonio Macias Ovalle

Oliva Rodríguez Montserrat

Pérez Alegría Haziel

Rodríguez Rangel José Emiliano

✔ Estado del Proyecto

 API funcionando

 Login seguro

 Flutter + API integrados

 GPS activo

 Fotos operativas

 Mapa funcional

 BD finalizada

 Mejoras opcionales futuras