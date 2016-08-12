# Project FPS

A very bare-bone prototype of a generic multiplayer FPS made with [CraftStudio](http://craftstud.io).

It was really meant to be a technical challenge for me as I never did a FPS before and I only ever did a multiplayer Pong.

And a challenge it was ! It’s definitely one of the most advanced and complex project I worked on so far but that also means that I learned so much !

Because it works … almost … kind of…

So far, as of August 2014 these features are working fine :

- Servers with config loadable from a .json file.
- Server Browser
- In-game chat
- Admin commands via the chat
- DM, TDM and CTF gametypes

But there is no client prediction/lag compensation, so it’s practically unplayable online and I am not even sure that the architecture of the network functions would allow to implement that easily.


To test the multiplayer, you have to open at least three window, one for the server and two for the clients. Note that the build does not seems to actually workl properly
