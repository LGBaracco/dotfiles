{
  enableFormat = true;
  enableTreesitter = true;
  enableExtraDiagnostics = true;

  nix.enable = true;
  nix.format.type = [ "nixfmt" ];

  python = {
    enable = true;
    format.type = [ "ruff" ];
    lsp.servers = [ "ty" ];
  };

  julia.enable = true;
  markdown.enable = true;
  bash.enable = true;
  fish.enable = true;
  clang.enable = true;
  cmake.enable = true;
  css.enable = true;
  html.enable = true;
  json.enable = true;
  sql.enable = true;
  java.enable = true;
  lua.enable = true;
  r.enable = true;
  toml.enable = true;
  xml.enable = true;
  tex.enable = true;
  docker.enable = true;
  env.enable = true;
  make.enable = true;
  qml.enable = true;

  typst.enable = false;
  scss.enable = false;
  kotlin.enable = false;
  typescript.enable = false;
  go.enable = false;
  rust.enable = false;
  zig.enable = false;
  openscad.enable = false;
  arduino.enable = false;
  assembly.enable = false;
  astro.enable = false;
  nu.enable = false;
  csharp.enable = false;
  vala.enable = false;
  scala.enable = false;
  gleam.enable = false;
  glsl.enable = false;
  dart.enable = false;
  ocaml.enable = false;
  elixir.enable = false;
  haskell.enable = false;
  hcl.enable = false;
  ruby.enable = false;
  fsharp.enable = false;
  just.enable = false;
  jinja.enable = false;
  svelte.enable = false;
  vue.enable = false;
  tsx.enable = false;
  liquid.enable = false;
  tera.enable = false;
  twig.enable = false;
  gettext.enable = false;
  fluent.enable = false;
  jq.enable = false;
  standard-ml.enable = false;
  pug.enable = false;
  zsh.enable = false;
}
