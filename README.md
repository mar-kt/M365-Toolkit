# M365 Toolkit 🚀

Un conjunto integral, modular y profesional de herramientas en **PowerShell 7+** diseñado para la administración avanzada, auditoría de seguridad, cumplimiento normativo (eDiscovery/Purview) e inventario en entornos **Microsoft 365 / Exchange Online**.

Diseñado para administradores de sistemas (SysAdmins), consultores e ingenieros de soporte que gestionan múltiples tenants y clientes con total aislamiento de datos.

---

## 🌟 Características Principales

### 🔒 Seguridad y Cumplimiento
- **Auditoría de Reenvíos**: Detección de redirecciones SMTP (servidor) y reglas de bandeja de entrada (cliente) hacia dominios externos o cuentas no autorizadas.
- **Control de Permisos de Delegación**: Auditoría de permisos `FullAccess` y `SendAs`, aislando accesos anómalos de las cuentas estándar del sistema.
- **Auditoría MFA Moderna (Microsoft Graph)**: Detección de métodos reales registrados (Microsoft Authenticator, FIDO2, Phone, Windows Hello), 100% compatible con directivas de Acceso Condicional y Security Defaults.
- **Extracción de Archivos Online (Purview / eDiscovery)**: Motor avanzado para consultar y exportar buzones de archivo histórico mediante traducción de identificadores EWS Base64 a consultas KQL hexadecimales optimizadas (`folderid:HEX`).

### 📦 Almacenamiento y Cuotas
- **Reporte Detallado de Buzones**: Análisis de tamaño de buzón principal, papelera/elementos eliminados, Sent Items, espacio libre y estado del buzón de archivo online.
- **Exportación Aislada por Cliente**: Generación automática de reportes en Excel estilizado (vía `ImportExcel`) o CSV UTF-8 organizados automáticamente por Cliente y Fecha (`output/<Cliente>/<YYYY-MM-DD>/`).

### 👤 Gestión de Identidades y Ciclo de Vida
- **Reciclaje de Cuentas (Offboarding / Reasignación)**: Renombrado seguro de usuarios para nuevos empleados, manteniendo el correo anterior como alias secundario (`smtp:alias`) y purgando datos personales residuales.
- **Detección de Cuentas Inactivas (Stale Mailboxes)**: Identificación de cuentas sin inicio de sesión (>90 días) para optimización y ahorro de licencias.
- **Inventario de Licencias Moderno (Microsoft Graph)**: Auditoría de SKUs asignadas con mapeo de nombres amigables (ej: `ENTERPRISEPACK`, `SPE_E3`).

### 💾 Backups Locales y Búsqueda Desconectada
- **Indexación SQLite**: Indexación ultrarrápida de paquetes de cumplimiento (`.zip`) en una base de datos relacional local (`backups.db`).
- **Búsqueda Histórica sin Conexión**: Motor de consulta por asunto, remitente o destinatario sin requerir conexión continua a la nube.
- **Dashboard de Respaldos**: Verificación de salud y detección de respaldos desactualizados (>30 días).

---

## 📁 Estructura del Proyecto

```text
M365-Toolkit/
├── Start-Console.ps1             # Lanzador rápido de la consola interactiva
├── src/
│   ├── ExchangeAdminTools/       # Módulo central reutilizable
│   │   ├── ExchangeAdminTools.psd1 # Manifiesto del módulo (v1.0.0)
│   │   ├── ExchangeAdminTools.psm1 # Cargador dinámico de funciones
│   │   └── Public/               # Funciones públicas exportadas
│   │       ├── Connect-Exchange.ps1
│   │       ├── Connect-M365Graph.ps1 # Conexión optimizada a Graph
│   │       ├── Disconnect-M365.ps1   # Cierre limpio de sesiones
│   │       ├── ConvertTo-Gb.ps1
│   │       └── Export-AdminReport.ps1 # Enrutamiento aislado por cliente
│   └── Scripts/                  # Suite de scripts operativos
│       ├── _Bootstrap.ps1        # Inicializador determinista del módulo
│       ├── Start-ExchangeConsole.ps1 # Consola interactiva (Menú CLI)
│       ├── Test-HealthCheck.ps1  # Verificación integral del sistema
│       ├── Start-ArchiveSearch.ps1
│       ├── Index-Backups.ps1
│       ├── Search-Backups.ps1
│       ├── Get-BackupReport.ps1
│       ├── Get-MailboxSizeReport.ps1
│       ├── Get-ForwardingReport.ps1
│       ├── Get-MailboxPermissionReport.ps1
│       ├── Get-StaleMailboxes.ps1
│       ├── Get-LicenseReport.ps1   # Basado en Microsoft.Graph.Users
│       ├── Get-MFAStatusReport.ps1 # Basado en Microsoft.Graph.Identity.SignIns
│       ├── Update-UserIdentity.ps1
│       └── Search-DeliveryStatus.ps1
├── templates/                    # Plantillas de exportación
│   └── MailboxReport.xltx
├── output/                       # Directorio de salida aislado (ignorado en Git)
│   └── <Cliente>/<YYYY-MM-DD>/   # Reportes organizados automáticamente
└── docs/                         # Documentación técnica adicional
```

---

## ⚙️ Requisitos

1. **PowerShell 7+** (`pwsh`)
2. **Módulos de PowerShell**:
   ```powershell
   # 1. Exchange Online Management (Mandatorio)
   Install-Module -Name ExchangeOnlineManagement -Scope CurrentUser

   # 2. Microsoft Graph (Submódulos ligeros y rápidos)
   Install-Module -Name Microsoft.Graph.Authentication -Scope CurrentUser
   Install-Module -Name Microsoft.Graph.Users -Scope CurrentUser
   Install-Module -Name Microsoft.Graph.Identity.SignIns -Scope CurrentUser

   # 3. Reportes en Excel Estilizado (Opcional, altamente recomendado)
   Install-Module -Name ImportExcel -Scope CurrentUser
   ```
3. **Herramientas Externas**:
   - `sqlite3` (requerido únicamente si se utiliza el indexador de copias de seguridad locales).

---

## 🚀 Inicio Rápido

### 1. Verificación del Entorno
Valida que todos los módulos y scripts cargan correctamente y sin errores de sintaxis:
```powershell
./src/Scripts/Test-HealthCheck.ps1
```

### 2. Consola Interactiva
Inicia el centro de comando para seleccionar cualquier tarea administrativa desde un menú guiado:
```powershell
./Start-Console.ps1
```

Desde la consola puedes:
- Presionar **`C`** para cambiar el nombre del cliente activo (todos los reportes se guardarán en `output/<Cliente>/<Fecha>/`).
- Presionar **`D`** para desconectar sesiones y purgar tokens en caché antes de cambiar de cliente.

### 3. Ejecución Directa de Scripts
Cada script puede invocarse de manera independiente pasando los parámetros correspondientes:
```powershell
# Auditoría de reenvíos anómalos
./src/Scripts/Get-ForwardingReport.ps1

# Auditoría moderna de métodos MFA
./src/Scripts/Get-MFAStatusReport.ps1

# Inventario de licencias M365
./src/Scripts/Get-LicenseReport.ps1

# Buscar buzones inactivos hace más de 60 días
./src/Scripts/Get-StaleMailboxes.ps1 -Days 60

# Búsqueda y exportación de archivo online
./src/Scripts/Start-ArchiveSearch.ps1 -UserUpn "usuario@empresa.com" -KickOffExport $true
```

---

## 🛡️ Seguridad y Privacidad

Este repositorio está configurado con reglas estrictas de `.gitignore` para garantizar que:
- Ninguna base de datos de correos (`*.db`), archivos de cumplimiento (`*.zip`), ni reportes de clientes (`*.csv`, `*.xlsx`, `*.json`) se guarden en el historial de Git.
- Las sesiones activas pueden purgarse en cualquier momento ejecutando `Disconnect-M365`.
- El código se mantiene completamente agnóstico y transferible entre diferentes organizaciones.
