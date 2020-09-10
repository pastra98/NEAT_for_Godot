# NEAT for Godot
An implementation of Kenneth O. Stanley's NEAT Algorithm for the Godot game engine,
written in gdscript. This code is intended to be easily appliable into godot
projects where the programmer wants to use neural networks to control agents.

Tested for godot 3.2.2

## How can I use this for my project?
Please refer to 
[first page](https://github.com/pastra98/NEAT_for_Godot/wiki/How-do-I-use-this-for-my-own-project%3F)
of the wiki.

## I just want to run the demos!
If you are not already using godot, I strongly recommend giving it a try, the download
page is [here](https://godotengine.org/download/). The binary is tiny (~61 mb)
and a portable install. It includes everything needed to run/edit the demos, or
even making your own games. Just import the project.godot file, and it should work.

However I have compiled binaries (the windows one is currently bugged, will fix this
soon), which you can find
[here](https://github.com/pastra98/NEAT_for_Godot/releases/tag/v1.0),
though I sincerely recommend running it in the editor for the reasons listed in the release.

## credits
The NEAT algorithm was originally conceived by
[Kenneth O. Stanley](https://www.cs.ucf.edu/~kstanley/).

Matt Buckland's [AI Techniques for Game Programming](https://www.amazon.de/Techniques-Programming-Premier-Press-Development/dp/193184108X)
inspired me to undertake this project, and the c++ snippets included in the NEAT
chapter were a great resource for starting off.

The font used in this project is google's
[roboto](https://fonts.google.com/specimen/Roboto)

And **of course** special thanks to the [godot](https://godotengine.org/) project
and all it's contributors.

### graphics
- Car sprites were made by the user unlucky studio on opengameart -
[link](https://opengameart.org/content/free-top-down-car-sprites-by-unlucky-studio)

- The explosion spritesheet used in the car and lander demo was made by
JRob774 on opengameart - 
[link](https://opengameart.org/content/pixel-explosion-12-frames)

- The moon texture was made by Murilo's Game Art -
[link](http://costamurilo.blogspot.com/2013/04/et49-week-10.html)

- The brain used in the projects logo was made by an unknown user on pixelartmaker - 
[link](http://pixelartmaker.com/art/2bb9b1edc81926c)

### script
- The car script is based off Ivan Skodje's 2d vehicle controller project -
[link](github.com/ivanskodje-godotengine/Vehicle-Controller-2D)

### Every other asset was made by me
