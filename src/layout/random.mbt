///|
/// シード固定の疑似乱数（mulberry32）。同じシードからは常に同じ列が得られる。
struct Random {
  mut state : UInt32
}

///|
/// `seed` から乱数列を作る。
pub fn Random::new(seed : Int32) -> Random {
  { state: seed.reinterpret_as_uint(), }
}

///|
/// 次の乱数を `[0, 1)` の範囲で返す。
///
/// ```mbt check
/// test {
///   let random = @layout.Random::new(1)
///   inspect(random.next_double(), content="0.6270739405881613")
/// }
/// ```
pub fn Random::next_double(self : Random) -> Double {
  self.state = self.state + 0x6d2b79f5U
  let seed = self.state
  let a = (seed ^ (seed >> 15)) * (seed | 1U)
  let b = (a + (a ^ (a >> 7)) * (a | 61U)) ^ a
  (b ^ (b >> 14)).to_double() / 4294967296.0
}
