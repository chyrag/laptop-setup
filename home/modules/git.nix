{ ... }:
{
  # Git identity requires --impure (reads GIT_USER_NAME, GIT_USER_EMAIL from env).
  # The raw gitconfig in dotfiles/git/gitconfig uses __GIT_USER__ and __GIT_EMAIL__
  # as placeholders; builtins.replaceStrings substitutes them at build time.
  home.file.".gitconfig".text = builtins.replaceStrings
    [ "__GIT_USER__" "__GIT_EMAIL__" ]
    [ (builtins.getEnv "GIT_USER_NAME") (builtins.getEnv "GIT_USER_EMAIL") ]
    (builtins.readFile ../../dotfiles/git/gitconfig);
}
