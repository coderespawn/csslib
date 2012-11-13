// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/** Common definitions used for setting up the test environment. */
library testing;

import 'package:csslib/parser.dart' as Css;
import 'package:csslib/src/messages.dart';

useMockMessages() {
  messages = new Messages(printHandler: (message) {});
}

Css.Stylesheet parseCss(String css, {List errs}) => Css.parse(css, errors:errs);
