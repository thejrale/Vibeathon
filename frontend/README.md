# Landing / presentación de arquitectura

Página estática (HTML + CSS + JS, sin dependencias ni build) que presenta la arquitectura offline-first de 3 capas: tablets con ODK Collect + SQLite, sincronización asíncrona con Valkey y servidor central ODK Central + PostgreSQL.

## Ver localmente

```bash
cd frontend
python3 -m http.server 8080
# abrir http://localhost:8080
```

También funciona abriendo `index.html` directamente en el navegador.

## Modo presentación

- `P` o botón **Presentar**: pantalla completa, una sección por diapositiva
- `←` `→` / `PageUp` `PageDown`: navegar
- `Esc`: salir

Nota: Valkey (capa 2) está fuera del alcance del MVP (`docs/MVP_SCOPE.md`); la página lo muestra como la arquitectura objetivo.
