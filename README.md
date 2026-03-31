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

### Recommended: Using Environment Variables (Decidim 31+)

Set the following environment variables directly:

```bash
DECIDIM_KEYCLOAK_CLIENT_ID=your_client_id
DECIDIM_KEYCLOAK_CLIENT_SECRET=your_client_secret
DECIDIM_KEYCLOAK_SITE=https://your-keycloak-server/realms/your-realm
DECIDIM_KEYCLOAK_REALM=your_realm
DECIDIM_KEYCLOAK_BASE_URL=https://your-keycloak-server  # Optional
```

### Legacy: Using secrets.yml (Decidim 30 and below)

If you're using Decidim 30 or earlier, add to your `config/secrets.yml`:

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

**Note:** The module will prioritize environment variables (`DECIDIM_KEYCLOAK_*`) over secrets.yml configuration for backwards compatibility.

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
