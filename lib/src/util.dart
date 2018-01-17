// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:io';
import 'package:charcode/ascii.dart' as ascii;
import 'package:shelf/shelf.dart';

DateTime toSecondResolution(DateTime dt) {
  if (dt.millisecond == 0) return dt;
  return dt.subtract(new Duration(milliseconds: dt.millisecond));
}

class ContentRanges {
  factory ContentRanges(Request request, int contentLength) {
    final header = request.headers[HttpHeaders.RANGE];

    if (header == null) {
      return const ContentRanges.none();
    }

    // HeaderValue parses the range header as a value, so we insert the value
    // terminator so `bytes=0-3` will be parsed as a parameter.
    final rangeHeader = HeaderValue.parse(";$header");
    final bytes = rangeHeader.parameters["bytes"];

    if (bytes == null) {
      return const ContentRanges.invalid();
    }

    int index = 0;

    bool indexIsOk() => index < bytes.length;

    bool isDigit(int codeUnit) => codeUnit >= ascii.$0 && codeUnit <= ascii.$9;
    bool isDash(int codeUnit) => codeUnit == ascii.$dash;
    bool isComma(int codeUnit) => codeUnit == ascii.$comma;

    void skipWs() {
      while (indexIsOk()) {
        final cu = bytes.codeUnitAt(index);
        if (cu == ascii.$space || cu == ascii.$tab) {
          index++;
        } else {
          break;
        }
      }
    }

    int acceptInt() {
      skipWs();

      int start = index;
      while (indexIsOk()) {
        final cu = bytes.codeUnitAt(index);
        if (isDigit(cu)) {
          index++;
        } else {
          break;
        }
      }
      return int.parse(bytes.substring(start, index), onError: (input) {
        if (input.isEmpty) {
          return -2;
        } else {
          return -1;
        }
      });
    }

    bool acceptDash() {
      skipWs();

      if (indexIsOk() && isDash(bytes.codeUnitAt(index))) {
        index++;
        return true;
      }
      return false;
    }

    bool acceptComma() {
      skipWs();

      if (indexIsOk() && isComma(bytes.codeUnitAt(index))) {
        index++;
        return true;
      }
      return false;
    }

    List<ByteRange> byteRanges = <ByteRange>[];

    do {
      int start = acceptInt();
      if (!acceptDash()) {
        return const ContentRanges.invalid();
      }
      int end = acceptInt();

      if (end == -2) {
        // No end specified, so use contentLength
        end = contentLength - 1;
      }

      ByteRange range = new ByteRange(start, end);

      if (!range.isValidFor(contentLength)) {
        return const ContentRanges.invalid();
      }

      byteRanges.add(range);
    } while (acceptComma());

    return new ContentRanges.valid(byteRanges);
  }

  final bool isValid;
  final List<ByteRange> ranges;

  const ContentRanges.none() : isValid = true, ranges = const <ByteRange>[];
  const ContentRanges.invalid() : isValid = false, ranges = const <ByteRange>[];
  const ContentRanges.valid(this.ranges) : isValid = true;

  bool get isEmpty => ranges.isEmpty;
  bool get isNotEmpty => ranges.isNotEmpty;
  int get length => ranges.length;
  ByteRange get single => ranges.single;

  bool get isInvalid => !isValid;
}

class ByteRange {
  final int start, end;
  const ByteRange(this.start, this.end);

  // 0-0: length 1
  // 1-0: invalid
  // 0-1: length 2

  bool get isValid => start <= end;
  int get length => end - start + 1;

  bool isValidFor(int contentLength) => isValid && end < contentLength;

  Stream<List<int>> openStream(File file) => file.openRead(start, end + 1);
}
