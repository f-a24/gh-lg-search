///|
using @html {button, canvas, div, form, img, input, li, p, span, ul}

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
/// 再生／一時停止のボタンと年スライダー。
fn controls_view(controls : Controls, emit : @cmd.Emit[Msg]) -> Html {
  let label = if controls.playing { "一時停止" } else { "再生" }
  div(class="controls", [
    button(
      class="play",
      type_="button",
      title=label,
      disabled=controls.still,
      attrs=@html.Attrs::build().aria_label(label),
      on_click=(emit.0)(TogglePlay),
      if controls.playing {
        "❚❚"
      } else {
        "▶"
      },
    ),
    input(
      class="year",
      input_type=Range,
      min=controls.first_year,
      max=controls.last_year,
      step=1,
      attrs=@html.Attrs::build()
        .aria_label("表示する年")
        .value_prop(controls.year.to_string()),
      on_input=emit.map(value => Seek(value)),
    ),
  ])
}

///|
/// 言語ごとの件数と割合。Canvas の外の DOM に常に表示する。
fn legend_view(stats : Array[@domain.LanguageStat]) -> Html {
  let total = stats.fold(init=0, (sum, stat) => sum + stat.count)
  ul(
    class="legend",
    [
      for stat in stats => {
        li([
          span(class="dot", style=["background:\{stat.color}"], ""),
          span(legend_text(stat, total)),
        ])
      }
    ],
  )
}

///|
fn shown_view(shown : Shown, emit : @cmd.Emit[Msg]) -> Html {
  div([
    profile_view(shown.profile),
    div(class="stage", [
      canvas(id=CANVAS_ID, ""),
      controls_view(shown.controls, emit),
    ]),
    legend_view(shown.stats),
  ])
}

///|
fn phase_view(phase : Phase, emit : @cmd.Emit[Msg]) -> Html {
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
    Showing(shown) => shown_view(shown, emit)
  }
}

///|
fn view(model : Model, emit : @cmd.Emit[Msg]) -> Html {
  div(class="page", [search_view(model, emit), phase_view(model.phase, emit)])
}
