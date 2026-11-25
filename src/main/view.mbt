///|
using @html {button, canvas, div, form, img, input, p}

///|
using @rabbita {type Html}

///|
const CANVAS_ID : String = "planets"

///|
/// ユーザー名の入力欄と検索ボタン。取得中は操作できない。
fn search_view(model : Model, emit : @cmd.Emit[Msg]) -> Html {
  let loading = model.phase is Loading(_)
  form(class="search", on_submit=(emit.0)(Submit), [
    input(
      class="query",
      input_type=Text,
      placeholder="ユーザー名を入力",
      attrs=@html.Attrs::build()
        .aria_label("GitHub のユーザー名")
        .disabled(loading)
        .value_prop(model.query),
      on_input=emit.map(value => QueryChanged(value)),
    ),
    button(class="submit", type_="submit", disabled=loading, "検索"),
  ])
}

///|
/// アバター、名前、login、bio。
fn profile_view(profile : @domain.Profile) -> Html {
  let name = match profile.name {
    Some(name) if name != "" => name
    _ => profile.login
  }
  div(class="profile", [
    img(
      class="avatar",
      src=profile.avatar_url,
      alt="\{profile.login} のアバター",
      width=56,
      height=56,
    ),
    div(class="who", [
      p(class="name", name),
      p(class="login", profile.login),
      match profile.bio {
        Some(bio) if bio != "" => p(class="bio", bio)
        _ => @html.nothing
      },
    ]),
  ])
}

///|
fn shown_view(shown : Shown) -> Html {
  div([
    profile_view(shown.profile),
    div(class="stage", [
      canvas(
        id=CANVAS_ID,
        attrs=@html.Attrs::build()
          .role("img")
          .aria_label(language_summary(shown.profile.login, shown.stats)),
        "",
      ),
    ]),
  ])
}

///|
fn phase_view(phase : Phase) -> Html {
  match phase {
    Idle => @html.nothing
    Loading(user) =>
      p(
        class="message",
        attrs=@html.Attrs::build().role("status"),
        "\{user} を読み込み中…",
      )
    Failed(failure) =>
      p(
        class="message error",
        attrs=@html.Attrs::build().role("alert"),
        failure.message(@ffi.format_time),
      )
    Showing(shown) => shown_view(shown)
  }
}

///|
fn view(model : Model, emit : @cmd.Emit[Msg]) -> Html {
  div(class="page", [
    // 画面全体の宇宙の背景。中身は `Backdrop` が描く
    canvas(
      id=BACKDROP_ID,
      class="space",
      attrs=@html.Attrs::build().aria_hidden("true"),
      "",
    ),
    search_view(model, emit),
    phase_view(model.phase),
  ])
}
