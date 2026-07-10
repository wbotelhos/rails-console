# Changelog

## 0.1.0

- Browser console over ActionCable with xterm.js frontend bundle.
- Broker process (`bundle exec rails_console`) with PTY, sandbox-by-default, and `unsafe!` / `safe!` to toggle write mode.
- Audit models (`rails_console_sessions`, `rails_console_log_lines`); mode toggles are recorded as `transition` log lines.
- Install generator for migrations and `config/initializers/rails_console.rb`.
- `authorize` and `current_user` receive the resolved user (HTTP and WebSocket).
- Default `user_class` is `User`; default socket is `tmp/sockets/rails_console.sock`.
