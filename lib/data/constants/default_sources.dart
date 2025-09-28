import 'package:manga_offline/domain/entities/manga_source.dart';
import 'package:manga_offline/domain/entities/source_capability.dart';

/// Built-in sources bundled with the application.
const List<MangaSource> kDefaultSources = <MangaSource>[
  MangaSource(
    id: 'olympus',
    name: 'Olympus Biblioteca',
    description:
        'Catálogo en español con actualizaciones periódicas y enfoque offline.',
    baseUrl: 'https://olympusbiblioteca.com',
    locale: 'es-ES',
    capabilities: <SourceCapability>[
      SourceCapability.catalog,
      SourceCapability.detail,
      SourceCapability.chapterDownload,
      SourceCapability.fullDownload,
    ],
  ),
];
