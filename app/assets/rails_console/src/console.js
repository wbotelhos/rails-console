import { createConsumer } from '@rails/actioncable';
import { FitAddon } from '@xterm/addon-fit';
import { Terminal } from '@xterm/xterm';

const RELOAD_MARKER = '\x00CONSOLE_RELOAD\x00';
const RETRY_DELAY = 3000;
const SPINNER_FRAMES = ['⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏'];
const SPINNER_INTERVAL = 90;

class RailsConsoleTerminal {
  constructor(element) {
    this.element = element;
    this.consumer = createConsumer();
  }

  connect() {
    this.openTerminal();
    this.subscribe();
  }

  disconnect() {
    window.removeEventListener('resize', this.onResize);

    clearTimeout(this.retryTimeout);
    this.stopSpinner();

    this.subscription?.unsubscribe();
    this.terminal?.dispose();
  }

  onData(data) {
    const bytes = new TextEncoder().encode(data);
    const binary = String.fromCharCode(...bytes);

    this.subscription.perform('receive', { bytes: btoa(binary) });
  }

  openTerminal() {
    this.fitAddon = new FitAddon();
    this.terminal = new Terminal({ cursorBlink: true });

    this.terminal.loadAddon(this.fitAddon);
    this.terminal.open(this.element);
    this.fitAddon.fit();
    this.terminal.focus();

    this.onResize = () => this.fitAddon.fit();

    window.addEventListener('resize', this.onResize);

    this.terminal.onData((data) => this.onData(data));
  }

  received(data) {
    if (data.error) {
      this.stopSpinner();
      this.showError(data.error);
    } else if (data.bytes) {
      this.writeBytes(data.bytes);
    }
  }

  showError(message) {
    this.terminal.write(`\r\n${message}\r\n`);

    this.subscription.unsubscribe();

    this.retryTimeout = setTimeout(() => this.subscribe(), RETRY_DELAY);
  }

  startSpinner() {
    let frame = 0;

    this.spinner = setInterval(() => {
      this.terminal.write(`\r\x1b[K\x1b[33m${SPINNER_FRAMES[frame]}\x1b[0m Booting console…`);

      frame = (frame + 1) % SPINNER_FRAMES.length;
    }, SPINNER_INTERVAL);
  }

  stopSpinner() {
    if (!this.spinner) {
      return;
    }

    clearInterval(this.spinner);

    this.spinner = null;

    this.terminal.write('\r\x1b[K');
  }

  subscribe() {
    this.startSpinner();

    this.subscription = this.consumer.subscriptions.create('RailsConsole::ConsoleChannel', {
      connected: () => {},
      disconnected: () => {},
      received: (data) => this.received(data),
    });
  }

  writeBytes(encoded) {
    let binary = atob(encoded);

    // The broker sends this marker when it swaps the session (e.g. on unsafe!). Reset the
    // screen and show the booting spinner again until the fresh console prints its output.
    if (binary.includes(RELOAD_MARKER)) {
      binary = binary.replaceAll(RELOAD_MARKER, '');

      this.terminal.reset();
      this.startSpinner();
    } else {
      this.stopSpinner();
    }

    const bytes = Uint8Array.from(binary, (char) => char.charCodeAt(0));

    this.terminal.write(bytes);
  }
}

document.addEventListener('DOMContentLoaded', () => {
  const element = document.querySelector('[data-rails-console]');

  if (!element) {
    return;
  }

  const terminal = new RailsConsoleTerminal(element);

  terminal.connect();

  window.addEventListener('beforeunload', () => terminal.disconnect());
});
