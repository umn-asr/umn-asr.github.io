---
layout: post
title: "Portable dotfiles with GNU Stow"
date: 2019-02-11
author: "Remy Abdullahi"
---

One of the most elusive ducks I've tried to corral in my computing life is good dotfile management. I've had a variety of half-hearted attempts at figuring this out, from git repos that I never remember to update, emails to myself and gists here and there.

I've been with my current work computer for just under two years, so I've built quite the comfortable development environment with it. My `.vimrc`, `.zshrc` and other configurations are Just Right. However, I'll soon have to swap out computers to have it repaired for hardware issues, meaning I'll have to scramble to have my dotfiles saved and stored somewhere, again.

I figured this was the best time to set my dotfile management situation straight once and for awhile. After doing some research, I came across [GNU Stow](https://www.gnu.org/software/stow/), _"a symlink farm manager which takes distinct packages of software...located in separate directories on the filesystem, and makes them appear to be installed in the same place"_.

In this post, I'll show I combined GNU Stow and git to have effortless and intuitive dotfile management that always stays up-to-date, across multiple machines.
