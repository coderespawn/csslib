// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/**
 * This is a helper for run.sh. We try to run all of the Dart code in one
 * instance of the Dart VM to reduce warm-up time.
 */
library run_impl;

import 'dart:io';
import 'package:unittest/unittest.dart';
import 'package:unittest/vm_config.dart';
import 'compiler_test.dart' as compiler_test;
import 'declaration_test.dart' as declaration_test;
import 'error_test.dart' as error_test;
import 'selector_test.dart' as selector_test;

main() {
  var args = new Options().arguments;

  var pattern = new RegExp(args.length > 0 ? args[0] : '.');

  useVmConfiguration();

  if (pattern.hasMatch('compiler_test.dart')) compiler_test.main();
  if (pattern.hasMatch('declaration_test.dart')) declaration_test.main();
  if (pattern.hasMatch('selector_test.dart')) selector_test.main();
  if (pattern.hasMatch('error_test.dart')) error_test.main();
}
