# terminalwire-rails

Drop-in [Terminalwire](https://terminalwire.com) integration for Rails — serve a
Thor CLI over Terminalwire straight from your Rails app. You write your CLI *in
your app* (calling your models and business logic directly); your users install
one small, self-updating client with a single `curl … | bash`.

```ruby
# Gemfile
gem "terminalwire-rails"
```

Then follow the Rails guide to mount your CLI and ship it.

## Documentation

- Rails guide: https://terminalwire.com/docs/rails
- Client manual: https://terminalwire.com/docs/client
- All docs: https://terminalwire.com/docs

## License

The Terminalwire **server** (this gem) is open source under the **Apache License
2.0** — free to use, modify, and self-host, including commercially.

The Terminalwire **client** your users install is proprietary, and only
Terminalwire distributes it. Shipping a **commercial** CLI to your users needs a
subscription, priced per active client install:

- Pricing & licensing: https://terminalwire.com/pricing
- Terms: https://terminalwire.com/terms — Privacy: https://terminalwire.com/privacy
