---
layout: post
title: "Using Hub"
date: 2017-10-06
author: "Ian Whitney"
---

I recorded a quick (3 minute) video for a lightning talk introducing [hub](https://hub.github.com), a GitHub CLI that I use all the time.

<iframe width="560" height="315" src="https://www.youtube.com/embed/SdbnNNeE7JM" frameborder="0" allowfullscreen></iframe>

The video is silent, but below is the transcript of what you hear if you heard me give this talk!

<!--break-->

## Transcript

Today I'm going to introduce a GitHub CLI tool that I use a lot, called Hub.

[0:09] First off, let's install it. I'm on OSX, so I install it via Homebrew. But if you're on Windows it can be installed via Chocolatey, or there are packages for various Linux flavors.

[0:22] Once it's installed we need to do some configuration to make Hub work properly with the U's Enterprise Github install. We can do that by setting the `GITHUB_HOST` value.

[0:33] Also nice, if we alias `hub` to `git`, then we get all of the `git` and `hub` commands by just typing `git`, which we're already used to typing.

[0:50] One of those `hub` commands is `clone`. A short-hand for checking out a repo. I'm going to use it to get a small project.

[0:58] Once cloned, I can `cd` into the project. I don't know what sort of changes this code needs, though. I can use another `hub` command to find out. `browse -- issues` will open up the project's Issues page.

[1:15] Ok, this project needs one small change. I can do that.

[1:23] First, I want to fork this project into my own account. Another `hub` command helps out here, `fork`. And now you can see that I have two remotes, my fork and the origin remote.

[1:40] I want to create a new branch, which I do with the default `checkout -b` command. Like I said earlier, we still have access to all of our familiar `git` commands.

[1:53] I quickly add the copyright info that the issue requested. Then stage and commitand push it up to my remote.

[2:30] And now another `hub` command. I use `pull-request` to create a PR from the command line.

[2:48] With my Pull Request made, I can use `browse -- pulls` to open up the list of all the project's PRs.

[2:50] And those are just a few of the features that `hub` offers contributors. It offers a lot more than I covered here. Check out their site [https://hub.github.com](https://hub.github.com) fore more!




