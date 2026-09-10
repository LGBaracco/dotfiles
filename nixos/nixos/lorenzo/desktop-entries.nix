{
  # Run neovim with (ghostty) terminal to avoid theming abominations
  xdg.desktopEntries.nvim = {
    name = "Neovim";
    genericName = "Text Editor";
    comment = "Edit text files";
    exec = "ghostty -e nvim %F";
    icon = "nvim";
    terminal = false;
    categories = [
      "Utility"
      "TextEditor"
    ];
    mimeType = [
      "text/plain"
      "text/english"
      "text/x-makefile"
      "text/x-c++hdr"
      "text/x-c++src"
      "text/x-chdr"
      "text/x-csrc"
      "text/x-java"
      "text/x-tex"
      "application/x-shellscript"
    ];
    settings = {
      Keywords = "Text;editor;";
      StartupNotify = "false";
    };
  };
}
