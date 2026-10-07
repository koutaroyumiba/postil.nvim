Output assets/postil-send.gif

Set Shell "zsh"
Set Width 1280
Set Height 720
Set FontFamily "IosevkaTerm Nerd Font"
Set FontSize 16
Set Framerate 30
Set TypingSpeed 45ms
Set Theme "Rose Pine"
Set Padding 16

Hide
Type "tmux kill-session -t postil-vhs-send 2>/dev/null || true"
Enter
Type "env -u TMUX -u TMUX_PANE tmux new-session -s postil-vhs-send 'nvim demo/example.lua'"
Enter
Sleep 3s
Type ":lua if Snacks and Snacks.notifier then Snacks.notifier.hide() end"
Enter
Sleep 250ms
Type ":"
Escape
Sleep 250ms
Show
Sleep 1s

Type "5G"
Sleep 400ms
Type "V5j"
Sleep 800ms
Type " as"
Sleep 1s

Type "Identify the locking bug in this function."
Enter
Type "Reply in one short sentence."
Sleep 700ms
Escape
Type ":w"
Enter
Sleep 12s

Hide
Ctrl+B
Type "d"
Sleep 500ms
Type "tmux kill-session -t postil-vhs-send"
Enter
