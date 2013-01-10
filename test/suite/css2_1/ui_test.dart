// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library suite_files;

import 'dart:io';

import 'package:unittest/unittest.dart';
import 'package:unittest/vm_config.dart';
import '../../testing.dart';
import '../suite_files.dart';

Map<String, Object> _ExeceptionMatches = {
  'outline-color-002.xht' : completeFixup,
  'outline-color-005.xht' : completeFixup,
  'outline-color-006.xht' : completeFixup,
  'outline-color-012.xht' : completeFixup,
  'outline-color-017.xht' : completeFixup,
  'outline-color-022.xht' : completeFixup,
  'outline-color-025.xht' : completeFixup,
};

main() {
  useVmConfiguration();
  useMockMessages();

  var suite = new Suite('css2_1/src/ui');
  suite.processTests(_ExeceptionMatches);
}