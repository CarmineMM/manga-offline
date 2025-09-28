import 'package:flutter/widgets.dart';

/// Signature for building a local cover widget when a cached image is present.
typedef LocalCoverBuilder =
    Widget Function(BuildContext context, String imagePath);

/// Optional override used during tests to replace the default [`Image.file`]
/// rendering when exercising the UI in environments without full IO support.
///
/// Leave as `null` in production so the widgets fall back to the platform
/// implementation.
LocalCoverBuilder? debugLocalCoverBuilderOverride;
