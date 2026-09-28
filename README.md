# Love extensions

Love extensions is a simple toolkit library that add more functions to the base love API

Lua language support dynamic additions to its table in runtime, with that in mind, you can inject more functions
inside the `love` table while the game is running.

for this case, I joined some functions I made and others to make a "big api styled bundle".

This bundle includes new categories:

- `love.ease` some easing functions, can be used for some cool animations
- `love.mixer` add a custom audio mixer in love, for some advanced audio management
- `love.system` add more functions to the base `love.system` table
- `love.graphics` add more functions to the base `love.graphics` table
- `love.math` add more functions to the base `love.math` table

## usage

to install and use this extension, simple clone the repo, move the folder inside your project.
after this, just add the `require 'love_extension'` inside your script to properly load the library.
