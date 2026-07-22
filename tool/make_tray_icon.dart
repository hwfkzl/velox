// 生成菜单栏托盘图标：从 app_icon.png 的四角 flood-fill，把与角相连的
// 白色区域抹成透明，得到四角透明的 tray_icon.png。中间的白色闪电被蓝色
// 包围、不与四角相连，因此不受影响。
//
// 用法：dart run tool/make_tray_icon.dart
import 'dart:collection';
import 'dart:io';

import 'package:image/image.dart' as img;

void main() {
  final src = img.decodePng(
    File('assets/icons/app_icon.png').readAsBytesSync(),
  );
  if (src == null) {
    stderr.writeln('无法解码 app_icon.png');
    exit(1);
  }
  final im = src.convert(numChannels: 4); // 确保 RGBA
  final w = im.width, h = im.height;

  bool whiteish(int x, int y) {
    final p = im.getPixel(x, y);
    return p.r > 200 && p.g > 200 && p.b > 200;
  }

  final visited = List.generate(h, (_) => List<bool>.filled(w, false));
  final queue = Queue<List<int>>();
  for (final c in [
    [0, 0],
    [w - 1, 0],
    [0, h - 1],
    [w - 1, h - 1],
  ]) {
    if (!visited[c[1]][c[0]] && whiteish(c[0], c[1])) {
      visited[c[1]][c[0]] = true;
      queue.add(c);
    }
  }
  var cleared = 0;
  while (queue.isNotEmpty) {
    final cur = queue.removeFirst();
    final x = cur[0], y = cur[1];
    im.setPixelRgba(x, y, 0, 0, 0, 0); // 透明
    cleared++;
    for (final d in [
      [1, 0],
      [-1, 0],
      [0, 1],
      [0, -1],
    ]) {
      final nx = x + d[0], ny = y + d[1];
      if (nx < 0 || ny < 0 || nx >= w || ny >= h) continue;
      if (visited[ny][nx]) continue;
      if (whiteish(nx, ny)) {
        visited[ny][nx] = true;
        queue.add([nx, ny]);
      }
    }
  }

  File('assets/icons/tray_icon.png').writeAsBytesSync(img.encodePng(im));
  stdout.writeln('tray_icon.png 已生成 ${w}x$h，透明化角落像素 $cleared 个');
}
