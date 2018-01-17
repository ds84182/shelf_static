import 'dart:async';
import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart';
import 'package:shelf_static/shelf_static.dart';

Future main(List<String> args) async {
  if (args.length < 1) {
    stderr.writeln("Usage: shelfhost [directory] [port: 8080]");
    stderr.writeln("       shelfhost [directory] [host: 0.0.0.0] [port: 8080]");
    exit(1);
  }

  var path = args[0];
  var host = "0.0.0.0";
  var port = 8080;

  if (args.length == 2) {
    var newPort = int.parse(args[1], onError: (s) => null);

    if (newPort == null) {
      host = args[1];
    } else {
      port = newPort;
    }
  } else if (args.length >= 3) {
    host = args[1];
    port = int.parse(args[2], onError: (val) {
      stdout.writeln('Could not parse port value "$val" into a number.');
      exit(1);
    });
  }

  var handler = const Pipeline()
      .addMiddleware(logRequests())
      .addHandler(createStaticHandler(path, listDirectories: true));

  serve(handler, host, port).then((server) {
    print('Serving at http://${server.address.host}:${server.port}');
  });
}
