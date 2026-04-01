# Decidim::Keycloak

OmniAuth strategy for Keycloak.

![Login with Keycloak](examples/login.png)

## Installation

Add this line to your application's Gemfile:

```ruby
gem "decidim-keycloak", git: "https://github.com/Platoniq/decidim-module-keycloak", branch: "main"
```

And then execute:

```bash
bundle
```

## Configuration

### Decidim v0.31+ (Environment Variables)

In Decidim v0.31, `config/secrets.yml` and `Rails.application.secrets` were removed.
This module now reads configuration from **environment variables** and registers the
Keycloak provider automatically via the engine.

#### Required environment variables

| Variable | Description | Required |
|---|---|---|
| `OMNIAUTH_KEYCLOAK_CLIENT_ID` | OAuth 2.0 Client ID from your Keycloak realm | Yes |
| `OMNIAUTH_KEYCLOAK_CLIENT_SECRET` | OAuth 2.0 Client Secret | Yes |
| `OMNIAUTH_KEYCLOAK_SITE` | Keycloak server URL (e.g. `https://keycloak.example.org`) | Yes |
| `OMNIAUTH_KEYCLOAK_REALM` | Keycloak realm name | Yes |
| `OMNIAUTH_KEYCLOAK_ENABLED` | Enable/disable the provider globally (`true`/`false`, default: `true`) | No |
| `OMNIAUTH_KEYCLOAK_BASE_URL` | Custom base URL, if different from site | No |

Example:

```bash
export OMNIAUTH_KEYCLOAK_ENABLED=true
export OMNIAUTH_KEYCLOAK_CLIENT_ID=my-decidim-client
export OMNIAUTH_KEYCLOAK_CLIENT_SECRET=super-secret
export OMNIAUTH_KEYCLOAK_SITE=https://keycloak.example.org
export OMNIAUTH_KEYCLOAK_REALM=my-realm
```

No additional initializer is needed — the engine handles provider registration and
middleware setup automatically when the gem is loaded.

#### How it works

1. The engine registers `:keycloakopenid` in `Decidim.omniauth_providers` at boot time
   using the `OMNIAUTH_KEYCLOAK_ENABLED` env var (defaults to `true`).
2. The OmniAuth middleware is added automatically.
3. At request time, the middleware resolves the current **organization** from the
   request host and reads per-organization provider settings from the database.
4. If organization-level values are present (configured via the Decidim System admin
   panel at `/system/organizations/:id/edit`), they take **precedence**.
5. If organization-level values are missing or blank, the ENV variable values are
   used as **global defaults / fallback**.

#### Organization-specific overrides

You can configure different Keycloak settings per organization in the Decidim System
admin panel under **Organizations → Edit → Omniauth settings**. The following fields
can be overridden per organization:

- Client ID
- Client Secret
- Site
- Realm
- Base URL

Values set in the admin UI are stored encrypted in the database and take precedence
over the ENV defaults at request time.

### Legacy: Using secrets.yml (Decidim 0.30 and below)

> **Deprecated.** This method is not supported in Decidim 0.31+.

If you're using Decidim 0.30 or earlier, add to your `config/secrets.yml`:

```yaml
  omniauth:
    keycloakopenid:
      enabled: true
      icon_path: media/images/keycloak_logo.svg
      client_id: <%= ENV["OMNIAUTH_KEYCLOAK_CLIENT_ID"] %>
      client_secret: <%= ENV["OMNIAUTH_KEYCLOAK_CLIENT_SECRET"] %>
      site: <%= ENV["OMNIAUTH_KEYCLOAK_SITE"] %>
      realm: <%= ENV["OMNIAUTH_KEYCLOAK_REALM"] %>
      base_url: <%= ENV["OMNIAUTH_KEYCLOAK_BASE_URL"] %>
```

### Organization-specific Configuration

You can use different values by organization. Configure it in `/system/organizations/:id/edit`:

![Login with Keycloak](examples/system_conf.gif)

## Contributing

See [Decidim](https://github.com/decidim/decidim).

### Developing

To start contributing to this project, first:

- Install the basic dependencies (such as Ruby and PostgreSQL)
- Clone this repository

Decidim's main repository also provides a Docker configuration file if you
prefer to use Docker instead of installing the dependencies locally on your
machine.

You can create the development app by running the following commands after
cloning this project:

```bash
$ bundle
$ DATABASE_USERNAME=<username> DATABASE_PASSWORD=<password> bundle exec rake development_app
```

Note that the database user has to have rights to create and drop a database in
order to create the dummy test app database.

Then to test how the module works in Decidim, start the development server:

```bash
$ cd development_app
$ DATABASE_USERNAME=<username> DATABASE_PASSWORD=<password> bundle exec rails s
```

In case you are using [rbenv](https://github.com/rbenv/rbenv) and have the
[rbenv-vars](https://github.com/rbenv/rbenv-vars) plugin installed for it, you
can add the environment variables to the root directory of the project in a file
named `.rbenv-vars`. If these are defined for the environment, you can omit
defining these in the commands shown above.

#### Code Styling

Please follow the code styling defined by the different linters that ensure we
are all talking with the same language collaborating on the same project. This
project is set to follow the same rules that Decidim itself follows.

[Rubocop](https://rubocop.readthedocs.io/) linter is used for the Ruby language.

You can run the code styling checks by running the following commands from the
console:

```
$ bundle exec rubocop
```

To ease up following the style guide, you should install the plugin to your
favorite editor, such as:

- Atom - [linter-rubocop](https://atom.io/packages/linter-rubocop)
- Sublime Text - [Sublime RuboCop](https://github.com/pderichs/sublime_rubocop)
- Visual Studio Code - [Rubocop for Visual Studio Code](https://github.com/misogi/vscode-ruby-rubocop)

### Testing

To run the tests run the following in the gem development path:

```bash
$ bundle
$ DATABASE_USERNAME=<username> DATABASE_PASSWORD=<password> bundle exec rake test_app
$ DATABASE_USERNAME=<username> DATABASE_PASSWORD=<password> bundle exec rspec
```

Note that the database user has to have rights to create and drop a database in
order to create the dummy test app database.

In case you are using [rbenv](https://github.com/rbenv/rbenv) and have the
[rbenv-vars](https://github.com/rbenv/rbenv-vars) plugin installed for it, you
can add these environment variables to the root directory of the project in a
file named `.rbenv-vars`. In this case, you can omit defining these in the
commands shown above.

## License

This engine is distributed under the [GNU AFFERO GENERAL PUBLIC LICENSE](LICENSE-AGPLv3.txt).
