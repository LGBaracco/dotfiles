{ lib }:

let
  inherit (lib) attrNames foldl' fromJSON readFile removePrefix stringLength substring toLower;

  hexDigit =
    c:
    let
      lower = toLower c;
      hex = "0123456789abcdef";
    in
    lib.findFirst (i: substring i 1 hex == lower) 0 (lib.genList (x: x) 16);

  hexToInt =
    hex:
    foldl' (acc: i: acc * 16 + hexDigit (substring i 1 hex)) 0 (lib.genList (x: x) (stringLength hex));

  hexToRgb =
    hex:
    let
      clean = toLower (removePrefix "#" hex);
      parse = off: substring off 2 clean;
    in
    {
      red = hexToInt (parse 0);
      green = hexToInt (parse 2);
      blue = hexToInt (parse 4);
    };

  loadThemeJson =
    path:
    let contents = readFile path;
    in
    if stringLength contents > 0 then fromJSON contents else throw "Empty theme.json at ${path}";

  loadSettingsJson =
    path:
    let contents = readFile path;
    in
    if stringLength contents > 0 then fromJSON contents else throw "Empty settings.json at ${path}";

  # Map DMS customThemeFile (/home/.../themes/<dir>/theme.json) onto the flake tree.
  resolveThemeJsonPath =
    dmsConfigDir: settings:
    let
      customThemeFile = settings.customThemeFile or null;
      matched =
        if customThemeFile == null || customThemeFile == "" then
          null
        else
          builtins.match ".*/(themes/[^/]+/theme\\.json)$" customThemeFile;
    in
    if matched == null then
      throw ''
        lorenzo/theming: DMS settings must set customThemeFile to a path under
        ~/.config/DankMaterialShell/themes/<name>/theme.json (got: ${
          if customThemeFile == null then "null" else customThemeFile
        }).
        Wallpaper/dynamic matugen themes are not supported for HM rebuild.
      ''
    else
      dmsConfigDir + "/${builtins.head matched}";

  # registryThemeVariants entry for this theme id, or multi/options defaults.
  resolveVariantSpec =
    themeJson: settings:
    let
      themeId = themeJson.id or null;
      fromSettings =
        if themeId == null then null else (settings.registryThemeVariants or { }).${themeId} or null;
      variants = themeJson.variants or { };
    in
    if fromSettings != null then
      fromSettings
    else if (variants.type or null) == "multi" then
      (variants.defaults or { })
    else if variants ? default then
      variants.default
    else
      null;

  findById =
    list: id:
    lib.findFirst (v: v.id == id) null list;

  findVariant =
    themeJson: variantId:
    findById (themeJson.variants.options or [ ]) variantId;

  mergeOptionsVariant =
    themeJson: variantId: mode:
    let
      variant = findVariant themeJson variantId;
      variantColors = if variant == null then { } else (variant.${mode} or { });
      base = themeJson.${mode} or { };
    in
    base // variantColors;

  mergeMultiVariant =
    themeJson: variantSpec: mode:
    let
      variants = themeJson.variants or { };
      modeSel =
        if builtins.isAttrs variantSpec then
          (variantSpec.${mode} or variantSpec.dark or { })
        else
          { };
      defaults = (variants.defaults or { }).${mode} or { };
      flavorId = modeSel.flavor or defaults.flavor or null;
      accentId = modeSel.accent or defaults.accent or null;
      flavor = if flavorId == null then null else findById (variants.flavors or [ ]) flavorId;
      accent = if accentId == null then null else findById (variants.accents or [ ]) accentId;
      flavorColors =
        if flavor == null then
          { }
        else
          # Flavor entries store mode colors under dark/light; some also put
          # all colors under the flavor id itself when light is empty.
          flavor.${mode} or { };
      accentColors =
        if accent == null || flavorId == null then
          { }
        else
          accent.${flavorId} or { };
      base = themeJson.${mode} or { };
    in
    base // flavorColors // accentColors;

  # variantSpec: null | string (options id) | attrs (multi { dark/light = { flavor, accent } })
  mergeTheme =
    themeJson: variantSpec: mode:
    let
      variants = themeJson.variants or { };
      isMulti = (variants.type or null) == "multi";
    in
    if variantSpec == null then
      themeJson.${mode} or { }
    else if isMulti || builtins.isAttrs variantSpec then
      mergeMultiVariant themeJson variantSpec mode
    else
      mergeOptionsVariant themeJson variantSpec mode;

  get =
    theme: key: fallback:
    theme.${key} or fallback;

  # Port of DMS Theme.qml buildMatugenColorsFromTheme()
  buildMatugenColors =
    {
      darkTheme,
      lightTheme,
      mode ? "dark",
    }:
    let
      isLight = mode == "light";
      pick = darkVal: lightVal: if isLight && lightVal != null then lightVal else darkVal;

      addColor =
        name: darkVal: lightVal:
        lib.optionalAttrs ((darkVal != null) || (lightVal != null)) {
          ${name} = {
            default = {
              hex = pick darkVal lightVal;
            }
            // hexToRgb (pick darkVal lightVal);
          };
        };

      colors =
        { }
        // addColor "primary" (get darkTheme "primary" null) (get lightTheme "primary" null)
        // addColor "on_primary" (get darkTheme "primaryText" null) (get lightTheme "primaryText" null)
        // addColor "primary_container" (get darkTheme "primaryContainer" null) (
          get lightTheme "primaryContainer" null
        )
        // addColor "on_primary_container" (get darkTheme "primaryContainerText" (get darkTheme "surfaceText" null)) (
          get lightTheme "primaryContainerText" (get lightTheme "surfaceText" null)
        )
        // addColor "secondary" (get darkTheme "secondary" null) (get lightTheme "secondary" null)
        // addColor "on_secondary" (get darkTheme "secondaryText" (get darkTheme "primaryText" null)) (
          get lightTheme "secondaryText" (get lightTheme "primaryText" null)
        )
        // addColor "secondary_container" (get darkTheme "secondaryContainer" (get darkTheme "surfaceContainerHigh" null)) (
          get lightTheme "secondaryContainer" (get lightTheme "surfaceContainerHigh" null)
        )
        // addColor "on_secondary_container" (get darkTheme "secondaryContainerText" (get darkTheme "surfaceText" null)) (
          get lightTheme "secondaryContainerText" (get lightTheme "surfaceText" null)
        )
        // addColor "tertiary" (get darkTheme "tertiary" (get darkTheme "secondary" null)) (
          get lightTheme "tertiary" (get lightTheme "secondary" null)
        )
        // addColor "on_tertiary" (get darkTheme "tertiaryText" (get darkTheme "secondaryText" (get darkTheme "primaryText" null))) (
          get lightTheme "tertiaryText" (get lightTheme "secondaryText" (get lightTheme "primaryText" null))
        )
        // addColor "tertiary_container" (get darkTheme "tertiaryContainer" (get darkTheme "secondaryContainer" (get darkTheme "surfaceContainerHigh" null))) (
          get lightTheme "tertiaryContainer" (
            get lightTheme "secondaryContainer" (get lightTheme "surfaceContainerHigh" null)
          )
        )
        // addColor "on_tertiary_container" (get darkTheme "tertiaryContainerText" (get darkTheme "surfaceText" null)) (
          get lightTheme "tertiaryContainerText" (get lightTheme "surfaceText" null)
        )
        // addColor "error" (get darkTheme "error" "#F2B8B5") (get lightTheme "error" "#B3261E")
        // addColor "on_error" (get darkTheme "errorText" "#601410") (get lightTheme "errorText" "#FFFFFF")
        // addColor "error_container" (get darkTheme "errorContainer" "#8C1D18") (
          get lightTheme "errorContainer" "#F9DEDC"
        )
        // addColor "on_error_container" (get darkTheme "errorContainerText" "#F9DEDC") (
          get lightTheme "errorContainerText" "#410E0B"
        )
        // addColor "surface" (get darkTheme "surface" null) (get lightTheme "surface" null)
        // addColor "on_surface" (get darkTheme "surfaceText" null) (get lightTheme "surfaceText" null)
        // addColor "surface_variant" (get darkTheme "surfaceVariant" null) (get lightTheme "surfaceVariant" null)
        // addColor "on_surface_variant" (get darkTheme "surfaceVariantText" null) (
          get lightTheme "surfaceVariantText" null
        )
        // addColor "surface_tint" (get darkTheme "surfaceTint" null) (get lightTheme "surfaceTint" null)
        // addColor "background" (get darkTheme "background" null) (get lightTheme "background" null)
        // addColor "on_background" (get darkTheme "backgroundText" null) (get lightTheme "backgroundText" null)
        // addColor "outline" (get darkTheme "outline" null) (get lightTheme "outline" null)
        // addColor "outline_variant" (get darkTheme "outlineVariant" (get darkTheme "surfaceVariant" null)) (
          get lightTheme "outlineVariant" (get lightTheme "surfaceVariant" null)
        )
        // addColor "surface_container" (get darkTheme "surfaceContainer" null) (
          get lightTheme "surfaceContainer" null
        )
        // addColor "surface_container_high" (get darkTheme "surfaceContainerHigh" null) (
          get lightTheme "surfaceContainerHigh" null
        )
        // addColor "surface_container_highest" (get darkTheme "surfaceContainerHighest" (get darkTheme "surfaceContainerHigh" null)) (
          get lightTheme "surfaceContainerHighest" (get lightTheme "surfaceContainerHigh" null)
        )
        // addColor "surface_container_low" (get darkTheme "surfaceContainerLow" (get darkTheme "surface" null)) (
          get lightTheme "surfaceContainerLow" (get lightTheme "surface" null)
        )
        // addColor "surface_container_lowest" (get darkTheme "surfaceContainerLowest" (get darkTheme "background" null)) (
          get lightTheme "surfaceContainerLowest" (get lightTheme "background" null)
        )
        // addColor "surface_bright" (get darkTheme "surfaceBright" (get darkTheme "surfaceContainerHighest" (get darkTheme "surfaceContainerHigh" null))) (
          get lightTheme "surfaceBright" (get lightTheme "surface")
        )
        // addColor "surface_dim" (get darkTheme "surfaceDim" (get darkTheme "background" null)) (
          get lightTheme "surfaceDim" (get lightTheme "surfaceContainer" null)
        )
        // addColor "inverse_surface" (get darkTheme "inverseSurface" (get lightTheme "surface" null)) (
          get lightTheme "inverseSurface" (get darkTheme "surface" null)
        )
        // addColor "inverse_on_surface" (get darkTheme "inverseOnSurface" (get lightTheme "surfaceText" null)) (
          get lightTheme "inverseOnSurface" (get darkTheme "surfaceText" null)
        )
        // addColor "inverse_primary" (get darkTheme "inversePrimary" (get lightTheme "primary" null)) (
          get lightTheme "inversePrimary" (get darkTheme "primary" null)
        )
        // addColor "scrim" (get darkTheme "scrim" "#000000") (get lightTheme "scrim" "#000000")
        // addColor "shadow" (get darkTheme "shadow" "#000000") (get lightTheme "shadow" "#000000")
        // addColor "source_color" (get darkTheme "primary" null) (get lightTheme "primary" null)
        // addColor "primary_fixed" (get darkTheme "primaryFixed" (get darkTheme "primaryContainer" null)) (
          get lightTheme "primaryFixed" (get lightTheme "primaryContainer" null)
        )
        // addColor "primary_fixed_dim" (get darkTheme "primaryFixedDim" (get darkTheme "primary" null)) (
          get lightTheme "primaryFixedDim" (get lightTheme "primary" null)
        )
        // addColor "on_primary_fixed" (get darkTheme "onPrimaryFixed" (get darkTheme "primaryText" null)) (
          get lightTheme "onPrimaryFixed" (get lightTheme "primaryText" null)
        )
        // addColor "on_primary_fixed_variant" (get darkTheme "onPrimaryFixedVariant" (get darkTheme "primaryText" null)) (
          get lightTheme "onPrimaryFixedVariant" (get lightTheme "primaryText" null)
        )
        // addColor "secondary_fixed" (get darkTheme "secondaryFixed" (get darkTheme "secondary" null)) (
          get lightTheme "secondaryFixed" (get lightTheme "secondary" null)
        )
        // addColor "secondary_fixed_dim" (get darkTheme "secondaryFixedDim" (get darkTheme "secondary" null)) (
          get lightTheme "secondaryFixedDim" (get lightTheme "secondary" null)
        )
        // addColor "on_secondary_fixed" (get darkTheme "onSecondaryFixed" (get darkTheme "primaryText" null)) (
          get lightTheme "onSecondaryFixed" (get lightTheme "primaryText" null)
        )
        // addColor "on_secondary_fixed_variant" (get darkTheme "onSecondaryFixedVariant" (get darkTheme "primaryText" null)) (
          get lightTheme "onSecondaryFixedVariant" (get lightTheme "primaryText" null)
        )
        // addColor "tertiary_fixed" (get darkTheme "tertiaryFixed" (get darkTheme "tertiary" (get darkTheme "secondary" null))) (
          get lightTheme "tertiaryFixed" (get lightTheme "tertiary" (get lightTheme "secondary" null))
        )
        // addColor "tertiary_fixed_dim" (get darkTheme "tertiaryFixedDim" (get darkTheme "tertiary" (get darkTheme "secondary" null))) (
          get lightTheme "tertiaryFixedDim" (get lightTheme "tertiary" (get lightTheme "secondary" null))
        )
        // addColor "on_tertiary_fixed" (get darkTheme "onTertiaryFixed" (get darkTheme "primaryText" null)) (
          get lightTheme "onTertiaryFixed" (get lightTheme "primaryText" null)
        )
        // addColor "on_tertiary_fixed_variant" (get darkTheme "onTertiaryFixedVariant" (get darkTheme "primaryText" null)) (
          get lightTheme "onTertiaryFixedVariant" (get lightTheme "primaryText" null)
        );
    in
    colors;

  renderTemplate =
    template: colors:
    foldl' (
      acc: token:
      let
        c = colors.${token}.default;
        replacements = [
          {
            from = "{{colors.${token}.default.hex}}";
            to = c.hex;
          }
          {
            from = "{{colors.${token}.default.red}}";
            to = toString c.red;
          }
          {
            from = "{{colors.${token}.default.green}}";
            to = toString c.green;
          }
          {
            from = "{{colors.${token}.default.blue}}";
            to = toString c.blue;
          }
        ];
      in
      foldl' (a: r: lib.replaceStrings [ r.from ] [ r.to ] a) acc replacements
    ) template (attrNames colors);

  generateFromTheme =
    {
      themeJsonPath,
      variant ? null,
      mode ? "dark",
      templates,
    }:
    let
      themeJson = loadThemeJson themeJsonPath;
      darkTheme = mergeTheme themeJson variant "dark";
      lightTheme = mergeTheme themeJson variant "light";
      colors = buildMatugenColors {
        inherit darkTheme lightTheme mode;
      };
      render = file: renderTemplate (readFile file) colors;
    in
    {
      inherit colors;
      gtkCss = render templates.gtk;
      kdeScheme = render templates.kde;
      kdeDarkScheme = render templates.kdeDark;
      qtCtConf = render templates.qtCt;
    };

  generateFromDmsSettings =
    {
      dmsConfigDir,
      mode ? "dark",
      templates,
    }:
    let
      settings = loadSettingsJson (dmsConfigDir + "/settings.json");
      themeJsonPath = resolveThemeJsonPath dmsConfigDir settings;
      themeJson = loadThemeJson themeJsonPath;
      variant = resolveVariantSpec themeJson settings;
    in
    generateFromTheme {
      inherit themeJsonPath variant mode templates;
    };

  kdeglobalsHeader =
    colorsContent: ''
      ${colorsContent}

      [General]
      ColorScheme=DankMatugenDark

      [KDE]
      LookAndFeelPackage=org.kde.breezedark.desktop
      contrast=4
      frameContrast=0.2
    '';

in
{
  inherit
    loadThemeJson
    loadSettingsJson
    resolveThemeJsonPath
    resolveVariantSpec
    mergeTheme
    buildMatugenColors
    renderTemplate
    generateFromTheme
    generateFromDmsSettings
    kdeglobalsHeader
    hexToRgb
    ;
}
