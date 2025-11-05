import 'dart:typed_data';
import 'dart:async';
import 'dart:html' as html;

/// Pick file on web using HTML file input
Future<Uint8List?> pickFileWeb() async {
  final completer = Completer<Uint8List?>();
  final input = html.FileUploadInputElement()
    ..accept = '.xlsx,.xls'
    ..click();
  
  input.onChange.listen((e) async {
    final files = input.files;
    if (files == null || files.isEmpty) {
      completer.complete(null);
      return;
    }
    
    final file = files[0];
    final reader = html.FileReader();
    
    reader.onLoadEnd.listen((e) {
      final result = reader.result;
      if (result is Uint8List) {
        completer.complete(result);
      } else {
        completer.complete(null);
      }
    });
    
    reader.onError.listen((e) {
      completer.complete(null);
    });
    
    reader.readAsArrayBuffer(file);
  });
  
  return completer.future;
}

