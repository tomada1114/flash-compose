# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Initial project scaffold from [ios-template](https://github.com/tomada1114/ios-template)
- The design lock's colors (ink accent, `Action`, `Good`, `OnGood`, `GoodEdge`,
  `InkSecondary`) and the "FC" placeholder app icon (Any, Dark, Tinted)
- Japanese beside English: on an iPhone set to Japanese every label is Japanese
- The drill: a Japanese prompt, 答えを見る (or a tap on the card) to reveal the model
  answer, its alternatives and point, and ×忘れた / △微妙 / ○覚えてた with the interval
  each would set; the counts 新規 › 復習 › もう一度 above the card; 今日の分は完了 with the
  next review day when nothing is left; a full-screen 再試行 when the data cannot be
  opened, and an alert when a grade cannot be saved

### Changed

- The app is iPhone only and portrait only; on an iPad it runs as an iPhone app
- The app now opens on the drill instead of the template's to-do list

[Unreleased]: https://github.com/tomada1114/flash-compose/commits/main
