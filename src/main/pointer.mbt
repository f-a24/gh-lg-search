///|
/// タッチで惑星や恒星を選ぶときに届く距離（px）。指で触れる大きさの半分。
const TOUCH_REACH : Double = 22.0

///|
/// ポインターの状態。
#derive(Debug, Eq)
enum Pointer {
  Away
  /// マウスの座標。動く惑星が下に来たら反応するよう、毎フレーム判定する
  Hovering(Double, Double)
  /// タップで選んだもの。惑星が動いてもツールチップが付いていく
  Pinned(@orbit.Hit)
}

///|
/// 今ツールチップを出す対象を返す。`year` より後に作成された惑星は対象にしない。
fn Pointer::target(
  self : Pointer,
  t : Double,
  year : Int32,
  planets : Array[@orbit.Planet],
  systems : Array[@layout.System],
  size : @layout.Canvas,
) -> @orbit.Hit? {
  match self {
    Away => None
    Hovering(x, y) => @orbit.hit_test(x, y, t, planets, systems, size, year)
    Pinned(Planet(index)) if planets[index].repo.created_year > year => None
    Pinned(hit) => Some(hit)
  }
}

///|
/// タップされた `hit` を受けて、次の状態と、開く惑星の添字を返す。
///
/// 1回目のタップはツールチップを出すだけで、選択中の惑星をもう一度タップすると開く。
/// 何もない場所をタップすると選択を解除する。
fn Pointer::tapped(self : Pointer, hit : @orbit.Hit?) -> (Pointer, Int32?) {
  match hit {
    None => (Away, None)
    Some(Planet(index)) if self == Pinned(Planet(index)) => (self, Some(index))
    Some(hit) => (Pinned(hit), None)
  }
}
