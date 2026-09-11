import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;

/// Navigator 뒤의 공통 배경을 페이지 전환 중에도 가리지 않는다.
///
/// Android의 예측 뒤로가기는 유지하면서 일반 이동의 단색 덮개만 없앤다.
/// 데스크톱의 기본 Zoom 전환은 배경색의 알파를 다시 지정하므로,
/// 투명 배경을 그대로 보존하는 FadeForwards 전환을 사용한다.
const appPageTransitionsTheme = PageTransitionsTheme(
  builders: <TargetPlatform, PageTransitionsBuilder>{
    TargetPlatform.android: PredictiveBackPageTransitionsBuilder(
      fallbackColor: Colors.transparent,
    ),
    TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(
      backgroundColor: Colors.transparent,
    ),
    TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(
      backgroundColor: Colors.transparent,
    ),
    TargetPlatform.fuchsia: FadeForwardsPageTransitionsBuilder(
      backgroundColor: Colors.transparent,
    ),
    TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
    TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
  },
);
