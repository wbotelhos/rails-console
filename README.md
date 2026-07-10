# Rails Console

[![Tests](https://github.com/wbotelhos/rails-console/workflows/Tests/badge.svg)](https://github.com/wbotelhos/rails-console/actions/workflows/tests.yml)
[![RuboCop](https://github.com/wbotelhos/rails-console/workflows/RuboCop/badge.svg)](https://github.com/wbotelhos/rails-console/actions/workflows/rubocop.yml)
[![Gem Version](https://badge.fury.io/rb/rails-console.svg)](https://badge.fury.io/rb/rails-console)
[![Maintainability](https://qlty.sh/gh/wbotelhos/projects/rails-console/maintainability.svg)](https://qlty.sh/gh/wbotelhos/projects/rails-console)
[![Coverage](https://codecov.io/gh/wbotelhos/rails-console/branch/main/graph/badge.svg)](https://codecov.io/gh/wbotelhos/rails-console)
[![Sponsor](https://img.shields.io/badge/sponsor-%3C3-green)](https://github.com/sponsors/wbotelhos)

A safe, browser-based Rails console you mount on your app.

## Installation

```ruby
gem 'rails-console'
```

```sh
bundle install
bin/rails generate rails_console:install
bin/rails db:migrate
```

## Mounting

Mount the engine behind your own authentication **and** authorization:

```ruby
# config/routes.rb
authenticate :user, ->(user) { user.devops? } do
  mount RailsConsole::Engine, at: :console
end
```

The route constraint protects the HTML page. The gem's `authorize` config (below) also protects the ActionCable channel — required because `/cable` is outside the mount.

## Configuration

Created by `bin/rails generate rails_console:install`. Example:

```ruby
# config/initializers/rails_console.rb
RailsConsole.configure do |config|
  config.audit = true

  config.authorize = ->(user) { user&.devops? }

  config.command = 'bundle exec rails console'

  config.current_user = ->(user) { { id: user&.id, label: user.try(:email) || 'unknown' } }

  config.idle_timeout = 10.minutes
  config.sandbox_command = 'bundle exec rails console --sandbox'
end
```

`authorize` and `current_user` receive the resolved user from HTTP (`request`) and WebSocket (`connection`) contexts.

| Option | Purpose |
| --- | --- |
| `audit` | Persist sessions and I/O log lines (default: `true`) |
| `authorize` | Proc `(user) -> bool` — may the user use the console (HTTP **and** WebSocket) |
| `command` | Command after `unsafe!` |
| `current_user` | Proc `(user) -> { id:, label: }` for audit records |
| `idle_timeout` | Kill idle PTY sessions after this duration |
| `sandbox_command` | Default command (safe-by-default sandbox) |
| `socket_path` | Unix socket between Puma workers and the broker (default: `tmp/sockets/rails_console.sock`) |
| `user_class` | ActiveRecord model class name for session `user` lookup (default: `User`) |

## Security layers

1. **Route constraint** — `authenticate` / custom constraint on the mount (HTTP only).
2. **Controller** — `authorize` runs again before rendering the page.
3. **Channel** — `authorize` on `subscribed` is the **only** protection for `/cable`; the mount does not cover WebSockets.

Additional safeguards:

- **Sandbox by default** — sessions start with `rails console --sandbox`.
- **`unsafe!` / `safe!`** — explicit toggle between write and sandbox mode; each swap starts a fresh PTY and is audited.
- **Broker isolation** — one PTY per container, shared via Unix socket across Puma workers.
- **Audit trail** — `RailsConsole::Session` and `RailsConsole::LogLine` when `audit` is enabled.

Do not rely on command filtering inside Ruby; use authorization + sandbox + auditing.

## Usage

Open `/console` (the path you mounted the engine at) to get a real `rails console` in the browser.

Sessions start in **safe mode** — changes are rolled back and never persisted:

```rb
User.last.destroy # runs, but nothing is saved
```

Type `unsafe!` to switch to **write mode**, where changes persist:

```rb
unsafe!
User.last.destroy # now really deletes the record
```

Type `safe!` to go back to sandbox mode. Each toggle starts a fresh session and is recorded in the audit trail.

## Broker process

The broker boots on demand when someone opens `/console`, or run it manually:

```sh
bundle exec rails_console
```

## Development (gem)

```sh
npm install
bundle exec rake assets:build # rebuild xterm bundle into app/assets/rails_console/
bundle exec rake spec
```
