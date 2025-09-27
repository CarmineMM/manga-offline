# Instrucciones para GitHub Copilot

-   Mantén la arquitectura limpia basada en separación de capas: presentation, domain y data.
-   Usa Isar para el almacenamiento local de referencias, estado y metadatos.
-   Prefiere la modularidad y el desacoplamiento en todos los módulos.
-   Documenta clases y funciones, sigue buenas prácticas de Dart/Flutter.
-   Usa nombres descriptivos y consistentes para carpetas, archivos y clases.
-   Cubre los casos de uso principales (listado, descarga, visualización offline, marcadores).
-   Cada nuevo módulo debe ser fácilmente testeable y extensible.

## Objetivo del Proyecto

Este repositorio implementa una aplicación móvil Flutter que permite a los usuarios explorar, descargar y leer mangas de forma totalmente offline. El enfoque principal es independiente de servidores externos: todos los mangas, capítulos e imágenes son obtenidos por scrapping o APIs, y posteriormente almacenados localmente. La solución debe ofrecer navegación fluida, descargas eficientes y experiencia de lectura cómoda sin requerir conexión a Internet.

### Finalidad

-   Garantizar que el usuario puede ver y leer cualquier manga previamente descargado aun sin conexión.
-   Brindar una biblioteca personalizable y persistente con referencias y estados actualizados en el dispositivo.
-   Facilitar la descarga eficiente (capítulos individuales o mangas completos) y la gestión de favoritos y progreso.
-   Optimizar el almacenamiento local y ofrecer una experiencia robusta y escalable.

### Tecnologías y métodos recomendados

-   Flutter y Dart para todo el código de la app móvil, siguiendo arquitectura limpia y modular.
-   Isar como base de datos local para almacenar referencias, metadatos y estados (descargado, leído, favorito).
-   Gestor de descargas local para imágenes y archivos asociados, manejando colas y notificaciones.
-   Fuentes dinámicas (scraper o API): los módulos para obtener datos de catálogos externos deben permitir extensión (plugins).
-   Gestión de assets locales: Imágenes y capítulos deben organizarse en carpetas internas, con referencias cruzadas seguras desde Isar.
-   Widgets desacoplados: La UI debe mantenerse reactiva y desacoplada del acceso a datos, vía controladores o proveedores.
-   Documentación clara en clases y funciones, siguiendo estilos Dart/Flutter.
-   Pruebas automatizadas para casos de uso críticos y módulos clave.
-   Live Share (VSCode) y convenciones de trabajo en ramas para pair programming.

### Notas adicionales

-   Mantén el código fácil de extender y documenta cualquier decisión relevante de arquitectura.
-   Prefiere métodos asíncronos donde sea viable para optimizar fluidez y experiencia UI.
-   Cualquier conversión de imágenes, parsing de datos externos o procesos IO deben ser modularizados.
-   Incluye ejemplos de uso en los docstrings o archivos de ayuda cuando crees abstracciones o utilidades importantes.

### Descripción de la estructura de archivos

El proyecto está organizado siguiendo la arquitectura limpia y el patrón Bloc para la gestión de estados, dividida en las siguientes capas principales:

#### data/

    Contiene la implementación concreta de acceso a datos. Aquí se separan:
    datasources/: módulos para obtener datos desde fuentes externas, como scrapers o APIs.
    repositories/: implementaciones concretas de repositorios que interactúan con datasources y la base de datos local (Isar).
    models/: modelos de datos que mapean la información recibida o almacenada.

#### domain/

Contiene la lógica de negocio pura, independiente de frameworks o tecnologías específicas:
entities/: definiciones de las entidades principales como Manga, Capítulo, Imagen.
usecases/: casos de uso que orquestan la lógica para funcionalidades clave (descargar capítulo, consultar manga, etc).
repositories/: interfaces abstractas que definen contratos para acceder a datos y deben implementarse en data/.

### presentation/

Contiene todo lo relacionado con la interfaz de usuario y gestión de estado:
blocs/: implementaciones de los Blocs que manejan estados y eventos, consumiendo casos de uso.
screens/: las pantallas o vistas principales, implementadas en Flutter, organizadas por funcionalidad (biblioteca, lista de capítulos, visor).
widgets/: componentes UI reutilizables.

#### core/

Contiene elementos compartidos y utilidades generales:
utils/: funciones y helpers comunes usados a lo largo del proyecto.
constants/: definiciones constantes globales, como strings, estilos y configuraciones.
errors/: manejo y definición de tipos de errores personalizados.
