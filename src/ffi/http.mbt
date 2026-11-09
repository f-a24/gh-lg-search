///|
/// HTTP の応答のうち、このアプリが使う部分。
/// レート制限のヘッダーがないときは `None`。
pub(all) struct HttpResponse {
  status : Int32
  ratelimit_remaining : String?
  ratelimit_reset : String?
  body : String
}

///|
#external
priv type JsResponse

///|
extern "js" fn fetch_all(
  urls : FixedArray[String],
) -> @js.Promise[FixedArray[JsResponse]] =
  #|(urls) => Promise.all(urls.map(async (url) => {
  #|  const response = await fetch(url);
  #|  return {
  #|    status: response.status,
  #|    remaining: response.headers.get('x-ratelimit-remaining') ?? '',
  #|    reset: response.headers.get('x-ratelimit-reset') ?? '',
  #|    body: await response.text(),
  #|  };
  #|}))

///|
extern "js" fn JsResponse::status(self : JsResponse) -> Int32 = "(r) => r.status"

///|
extern "js" fn JsResponse::remaining(self : JsResponse) -> String = "(r) => r.remaining"

///|
extern "js" fn JsResponse::reset(self : JsResponse) -> String = "(r) => r.reset"

///|
extern "js" fn JsResponse::body(self : JsResponse) -> String = "(r) => r.body"

///|
/// JS 側でヘッダーなしを空文字列にしているので、`None` に戻す。
fn header_value(value : String) -> String? {
  if value == "" {
    None
  } else {
    Some(value)
  }
}

///|
/// すべての `urls` を並列に GET し、同じ順序で応答を返す。
/// 通信に失敗した（`fetch` が reject した）ときは例外を投げる。
/// 404 などの HTTP エラーは失敗ではなく、応答として返す。
pub async fn http_get_all(urls : Array[String]) -> Array[HttpResponse] {
  let responses = fetch_all(FixedArray::from_array(urls)).wait()
  [
    for response in responses => {
      {
        status: response.status(),
        ratelimit_remaining: header_value(response.remaining()),
        ratelimit_reset: header_value(response.reset()),
        body: response.body(),
      }
    }
  ]
}

///|
/// URL の1区間として安全な形に文字列を符号化する。
pub extern "js" fn encode_uri_component(text : String) -> String = "(text) => encodeURIComponent(text)"
