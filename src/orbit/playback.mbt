///|
/// 最も古い年から最後の年まで再生する長さ（秒）。
pub const PLAYBACK_SECONDS : Double = 10.0

///|
/// 惑星が出現してから最大の大きさになるまでの長さ（秒）。
/// プロトタイプの 30 フレームを 60fps で秒に直した値。
const GROW_SECONDS : Double = 0.5

///|
/// 年の境目の時刻に足す年数。丸め誤差で `year_at` が1年前を返さないようにする。
const YEAR_START_MARGIN : Double = 1.0e-9

///|
/// 再生の状態。年・惑星の位置・出現の大きさは、すべて時刻 `t` から求める。
///
/// `t` は再生を始めてからの秒数で、再生が終わったあとも公転のために増え続ける。
/// 値は不変で、再生・一時停止・移動のたびに新しい値を作る。`clock` は
/// 単調に増える時計の秒数で、基準はどこでもよい。
#derive(Debug, Eq)
pub struct Playback {
  first_year : Int32
  last_year : Int32
  /// この年までの惑星は出現の途中を見せず、最初から最大の大きさで描く
  settled_year : Int32
  /// 時計が `origin_clock` のときの `t`
  origin_t : Double
  origin_clock : Double
  running : Bool
}

///|
pub extend Playback with @debug.Debug::{to_repr}

///|
pub extend Playback with Eq::{equal, not_equal}

///|
/// 最初の年から再生を始める。
pub fn Playback::start(
  first_year : Int32,
  last_year : Int32,
  clock : Double,
) -> Playback {
  {
    first_year,
    last_year,
    settled_year: first_year - 1,
    origin_t: 0.0,
    origin_clock: clock,
    running: true,
  }
}

///|
/// 再生せず、すべての惑星が揃った最終状態で止めておく。
pub fn Playback::finished(first_year : Int32, last_year : Int32) -> Playback {
  {
    first_year,
    last_year,
    settled_year: last_year,
    origin_t: PLAYBACK_SECONDS,
    origin_clock: 0.0,
    running: false,
  }
}

///|
/// 再生中なら `true`。
pub fn Playback::is_running(self : Playback) -> Bool {
  self.running
}

///|
/// 時計が `clock` のときの時刻 `t`（秒）を返す。一時停止中は変わらない。
///
/// rAF の時刻は `clock` を取った時点より少し前のことがあるので、`t` は戻さない。
pub fn Playback::time(self : Playback, clock : Double) -> Double {
  if self.running {
    self.origin_t + @cmp.maximum(0.0, clock - self.origin_clock)
  } else {
    self.origin_t
  }
}

///|
/// 時計が `clock` のときに表示する年を返す。
pub fn Playback::year(self : Playback, clock : Double) -> Int32 {
  year_at(self.time(clock) / PLAYBACK_SECONDS, self.first_year, self.last_year)
}

///|
/// `year` が始まる時刻 `t`（秒）を返す。`year_at` の逆関数にあたる。
fn Playback::year_start(self : Playback, year : Int32) -> Double {
  if year <= self.first_year {
    return 0.0
  }
  let span = (self.last_year - self.first_year).to_double() + LAST_YEAR_SHARE
  let offset = (year - self.first_year).to_double() + YEAR_START_MARGIN
  offset / span * PLAYBACK_SECONDS
}

///|
/// 作成年が `created_year` の惑星の大きさの倍率（0〜1）を返す。
///
/// 作成年の始まりから `GROW_SECONDS` かけて 0 から 1 になる。`t` だけで
/// 決まるので、途中で止めると大きくなる途中のまま止まる。
pub fn Playback::planet_scale(
  self : Playback,
  created_year : Int32,
  clock : Double,
) -> Double {
  if created_year <= self.settled_year {
    return 1.0
  }
  let grown = (self.time(clock) - self.year_start(created_year)) / GROW_SECONDS
  @cmp.maximum(0.0, @cmp.minimum(1.0, grown))
}

///|
/// 今の時刻で止める。
pub fn Playback::pause(self : Playback, clock : Double) -> Playback {
  { ..self, origin_t: self.time(clock), origin_clock: clock, running: false, }
}

///|
/// 止めた時刻から再生を続ける。
pub fn Playback::play(self : Playback, clock : Double) -> Playback {
  { ..self, origin_t: self.time(clock), origin_clock: clock, running: true, }
}

///|
/// `year` の始まりへ移動して止める。
///
/// `year` までの惑星は最大の大きさで見せる。範囲外の年は最初か最後の年に丸める。
/// 操作中に年が進むとスライダーのつまみと競合するので、移動すると再生は止まる。
pub fn Playback::seek(
  self : Playback,
  year : Int32,
  clock : Double,
) -> Playback {
  let year = @cmp.maximum(self.first_year, @cmp.minimum(self.last_year, year))
  {
    ..self,
    settled_year: year,
    origin_t: self.year_start(year),
    origin_clock: clock,
    running: false,
  }
}
