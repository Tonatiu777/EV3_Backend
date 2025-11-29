import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';

// Mapa
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as latlng;

// CAMBIA ESTA URL A LA IP DE TU API
const String apiBaseUrl = "http://192.168.56.1:8000";

void main() {
  runApp(const PaquexpressApp());
}

class PaquexpressApp extends StatelessWidget {
  const PaquexpressApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "Paquexpress EV3",
      debugShowCheckedModeBanner: false,
      home: const LoginPage(),
    );
  }
}

// ======================= LOGIN ==========================

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final userCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  bool loading = false;
  String? errorMsg;

  Future<void> _login() async {
    setState(() {
      loading = true;
      errorMsg = null;
    });

    try {
      final url = Uri.parse("$apiBaseUrl/login");
      final resp = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "username": userCtrl.text.trim(),
          "password": passCtrl.text.trim(),
        }),
      );

      if (resp.statusCode == 200) {
        final data = jsonDecode(utf8.decode(resp.bodyBytes));
        final int userId = data["user_id"];
        final String fullName = data["full_name"] ?? data["username"];

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => HomePage(userId: userId, fullName: fullName),
          ),
        );
      } else {
        setState(() {
          errorMsg = "Credenciales inválidas (${resp.statusCode})";
        });
      }
    } catch (e) {
      setState(() {
        errorMsg = "Error de conexión: $e";
      });
    } finally {
      setState(() {
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Login Paquexpress")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: userCtrl,
              decoration: const InputDecoration(labelText: "Usuario"),
            ),
            TextField(
              controller: passCtrl,
              decoration: const InputDecoration(labelText: "Contraseña"),
              obscureText: true,
            ),
            const SizedBox(height: 16),
            loading
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: _login,
                    child: const Text("Iniciar sesión"),
                  ),
            if (errorMsg != null) ...[
              const SizedBox(height: 8),
              Text(
                errorMsg!,
                style: const TextStyle(color: Colors.red),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ======================= HOME ==========================

class HomePage extends StatefulWidget {
  final int userId;
  final String fullName;

  const HomePage({super.key, required this.userId, required this.fullName});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List paquetes = [];
  bool loading = false;

  Future<void> _cargarPaquetes() async {
    setState(() => loading = true);
    try {
      final url = Uri.parse("$apiBaseUrl/packages/${widget.userId}");
      final resp = await http.get(url);
      if (resp.statusCode == 200) {
        setState(() {
          paquetes = jsonDecode(utf8.decode(resp.bodyBytes));
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error al cargar paquetes: ${resp.statusCode}")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error de conexión: $e")),
      );
    } finally {
      setState(() => loading = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _cargarPaquetes();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Paquetes de ${widget.fullName}"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _cargarPaquetes,
          )
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : paquetes.isEmpty
              ? const Center(child: Text("No hay paquetes asignados"))
              : ListView.builder(
                  itemCount: paquetes.length,
                  itemBuilder: (context, index) {
                    final p = paquetes[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      child: ListTile(
                        title: Text(p["tracking_code"] ?? ""),
                        subtitle: Text(p["destino"] ?? ""),
                        trailing: Text(p["estatus"] ?? ""),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => EntregaPage(
                                userId: widget.userId,
                                paquete: Map<String, dynamic>.from(p),
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
    );
  }
}

// ======================= ENTREGAR PAQUETE + MAPA ==========================

class EntregaPage extends StatefulWidget {
  final int userId;
  final Map<String, dynamic> paquete;

  const EntregaPage({super.key, required this.userId, required this.paquete});

  @override
  State<EntregaPage> createState() => _EntregaPageState();
}

class _EntregaPageState extends State<EntregaPage> {
  final ImagePicker _picker = ImagePicker();
  XFile? _pickedFile;
  File? _imageFile;
  double? _lat;
  double? _lon;
  bool sending = false;
  String status = "Toma la foto y registra la ubicación.";

  Future<void> _tomarFoto() async {
    final picked = await _picker.pickImage(source: ImageSource.camera);
    if (picked != null) {
      setState(() {
        _pickedFile = picked;
        _imageFile = File(picked.path);
      });
    }
  }

  Future<void> _obtenerGPS() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() {
        status = "Activa el GPS para continuar.";
      });
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() => status = "Permiso de ubicación denegado.");
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      setState(() => status = "Permiso de ubicación denegado permanentemente.");
      return;
    }

    final pos = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    setState(() {
      _lat = pos.latitude;
      _lon = pos.longitude;
      status = "Ubicación obtenida.";
    });
  }

  Future<void> _entregar() async {
    if (_pickedFile == null || _imageFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Primero toma la foto")),
      );
      return;
    }
    if (_lat == null || _lon == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Primero obtiene el GPS")),
      );
      return;
    }

    setState(() {
      sending = true;
      status = "Enviando entrega...";
    });

    try {
      final url = Uri.parse("$apiBaseUrl/deliveries/");
      final request = http.MultipartRequest("POST", url);

      request.fields["user_id"] = widget.userId.toString();
      request.fields["package_id"] =
          widget.paquete["package_id"].toString();
      request.fields["latitude"] = _lat.toString();
      request.fields["longitude"] = _lon.toString();

      request.files.add(
        await http.MultipartFile.fromPath("file", _imageFile!.path),
      );

      final resp = await request.send();
      final body = await resp.stream.bytesToString();

      if (resp.statusCode == 200) {
        setState(() {
          status = "Entrega registrada correctamente.\n$body";
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Paquete entregado ✔")),
        );
      } else {
        setState(() {
          status = "Error al registrar: ${resp.statusCode}\n$body";
        });
      }
    } catch (e) {
      setState(() {
        status = "Error de conexión: $e";
      });
    } finally {
      setState(() {
        sending = false;
      });
    }
  }

  Widget _buildMapa() {
    if (_lat == null || _lon == null) {
      return const Text(
        "Aún no hay ubicación. Presiona 'Obtener GPS' para ver el mapa.",
        textAlign: TextAlign.center,
      );
    }

    final point = latlng.LatLng(_lat!, _lon!);

    return SizedBox(
      height: 250,
      child: FlutterMap(
        options: MapOptions(
          initialCenter: point,
          initialZoom: 17,
          interactionOptions:
              const InteractionOptions(flags: InteractiveFlag.all),
        ),
        children: [
          TileLayer(
            urlTemplate: "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
            subdomains: const ['a', 'b', 'c'],
          ),
          MarkerLayer(
            markers: [
              Marker(
                point: point,
                width: 40,
                height: 40,
                child: const Icon(
                  Icons.location_pin,
                  size: 40,
                  color: Colors.red,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.paquete;

    return Scaffold(
      appBar: AppBar(
        title: Text("Entrega ${p["tracking_code"] ?? ""}"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              p["destino"] ?? "",
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _imageFile == null
                ? const Text("Sin foto")
                : Image.file(_imageFile!, height: 180),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _tomarFoto,
              child: const Text("Tomar foto"),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _obtenerGPS,
              child: const Text("Obtener GPS"),
            ),
            const SizedBox(height: 4),
            Text("Lat: ${_lat ?? '-'}, Lon: ${_lon ?? '-'}"),
            const SizedBox(height: 8),
            // Mapa interactivo
            _buildMapa(),
            const SizedBox(height: 8),
            sending
                ? const CircularProgressIndicator()
                : ElevatedButton.icon(
                    onPressed: _entregar,
                    icon: const Icon(Icons.check),
                    label: const Text("Paquete entregado"),
                  ),
            const SizedBox(height: 8),
            Text(
              status,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
