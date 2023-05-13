import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:http/http.dart' as http;
import 'package:mason_logger/mason_logger.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_multipart/form_data.dart';
import 'package:shelf_router/shelf_router.dart';

class PublishCommand extends Command<int> {
  PublishCommand({required Logger logger}) : _logger = logger;

  final Logger _logger;

  @override
  String get description => 'Publishes a package';

  @override
  String get name => 'publish';

  @override
  FutureOr<int> run() async {
    final server = SimplePubServer(_logger);
    await server.start();

    final process = await Process.start(
      'dart',
      [
        'pub',
        'publish',
        //'--dry-run',
        //'--force',
        '--server=${server.address}',
      ],
      runInShell: true,
    );
    process.stdin.addStream(stdin);
    process.stderr.forEach((data) => stderr.write(utf8.decode(data)));
    process.stdout.forEach((data) => stdout.write(utf8.decode(data)));

    final exitCode = await process.exitCode;

    return exitCode;
  }
}

/// Simple Pub Server
/// Handler for pub-spec protocol
/// https://github.com/dart-lang/pub/blob/master/doc/repository-spec-v2.md
class SimplePubServer {
  SimplePubServer(this.logger);

  final Logger logger;
  late HttpServer _server;

  Uri get address => Uri.http('${_server.address.host}:${_server.port}');

  Future<void> start() async {
    _server = await shelf_io.serve(
      const Pipeline() //
          .addMiddleware(_requestLogger())
          .addHandler(
            Router(notFoundHandler: _notFound) //
              ..get('/api/packages/versions/new', _createNew)
              ..get('/api/packages/<package>', _packageInfo)
              ..post('/upload', _uploadData)
              ..get('/finalize', _finalizeUpload),
          ),
      InternetAddress.loopbackIPv4,
      0,
    );
    print('Server: $address');
  }

  Middleware _requestLogger() {
    return logRequests(
      logger: (String message, bool isError) {
        if (isError) {
          logger.err(message);
        } else {
          logger.info(message);
        }
      },
    );
  }

  Response _notFound(Request request) {
    return Response(
      HttpStatus.notFound,
      body: json.encode({
        'error': {
          'code': HttpStatus.notFound,
          'message': '${request.url.path} Not Found',
        },
      }),
      headers: {
        HttpHeaders.contentTypeHeader: ContentType.json.mimeType,
      },
    );
  }

  Response _createNew(Request request) {
    return Response(
      HttpStatus.ok,
      body: json.encode({
        'url': address.replace(path: '/upload').toString(),
        'fields': {},
      }),
      headers: {
        HttpHeaders.contentTypeHeader: ContentType.json.mimeType,
      },
    );
  }

  Future<Response> _packageInfo(Request request) async {
    final result = await http.get(Uri.parse(
      'https://fluttercommunity.github.io/pubbie${request.url.path}',
    ));
    return Response(result.statusCode, body: result.body);
  }

  Future<Response> _uploadData(Request request) async {
    if (!request.isMultipartForm) {
      return Response(HttpStatus.notAcceptable);
    }
    final file = await request.multipartFormData //
        .singleWhere((part) => part.name == 'file');

    // FIXME: Store uploaded file
    final data = await file.part.readBytes();
    print('Received ${file.filename} => ${data.length}');

    return Response(
      HttpStatus.noContent,
      headers: {
        HttpHeaders.locationHeader:
            address.replace(path: '/finalize').toString()
      },
    );
  }

  Response _finalizeUpload(Request request) {
    return Response(
      HttpStatus.ok,
      body: json.encode({
        'success': {
          'message': 'It uploaded great!',
        },
      }),
      headers: {
        HttpHeaders.contentTypeHeader: ContentType.json.mimeType,
      },
    );
  }
}
