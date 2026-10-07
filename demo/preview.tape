Output assets/postil-preview.gif

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
Type "tmux kill-session -t postil-vhs-preview 2>/dev/null || true"
Enter
Type "env -u TMUX -u TMUX_PANE tmux new-session -s postil-vhs-preview 'nvim demo/example.lua'"
Enter
Sleep 2s
Type ":lua if Snacks and Snacks.notifier then Snacks.notifier.hide() end"
Enter
Sleep 250ms
Type ":"
Escape
Sleep 250ms
Show
Sleep 1s

Type "5G"
Sleep 500ms
Type "V5j"
Sleep 1s
Type " ap"
Sleep 1s

Type "Explain why this lock ordering can deadlock."
Enter
Type "Suggest a safer locking strategy."
Sleep 1s
Escape
Type ":w"
Enter
Sleep 4s

Hide
Ctrl+B
Type "d"
Sleep 500ms
Type "tmux kill-session -t postil-vhs-preview"
Enter
