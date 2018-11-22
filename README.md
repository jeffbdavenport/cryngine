# Cryngine

An advanced free 3D game engine in development built on top of OpenGL. With the goal in mind of convention, speed, and high quality over configuration, as well as a means to serve as a solid alternative to production grade game engines.

Conventions and beliefs in mind thus far

- Engine will only be designed to work for Linux
  - Designed for:
    - ext4, X11, sqlite3, 
- Gamers do not care most about graphics, they care about a game that runs well and has great Gameplay
  - OpenGL is not as advanced as Direct X 12, however most of the features provided there, gamers will not miss.
  - In my experience OpenGL has much better performance than Direct X
  
- Developers don't want to have to develop software to support multiple platforms such as MacOS, Windows, and Linux.
  - Linux is free and anyone can install it. If they care about the game enough, they will try Linux.
  - Most people using MacOS won't want to have to purchase Windows just to play the game, and most people on Windows won't want to have to pruchase a Mac just to play the game they want. But both of the two would consider installing Linux.

## Installation

Add this to your application's `shard.yml`:

```yaml
dependencies:
  cryngine:
    github: jeffreydvp/cryngine
```

## Usage

```crystal
require "cryngine"
```


## Development

See Contributing below

## Contributing

1. Fork it (<https://github.com/jeffreydvp/cryngine/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [jeffreydvp](https://github.com/jeffreydvp) Jeff Davenport - creator, maintainer
