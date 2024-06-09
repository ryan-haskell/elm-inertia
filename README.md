# **@ryan-haskell/elm-inertia**

A package for using Elm with [Inertia](https://inertiajs.com/) (Work with Laravel, Rails, and more!)


## **Local installation**

```
elm install ryan-haskell/elm-inertia
```

**Note:** This works alongside the companion [NPM Package](https://www.npmjs.com/package/elm-inertia).


## **Overview**

This package was created to help folks with Laravel/Rails/Django experience become productive with Elm. Inertia provides a simple way to enhance your existing server-side apps, without the need for REST or GraphQL API.

![PingCRM demo application](https://github.com/ryan-haskell/elm-inertia/blob/main/example/pingcrm-elm.gif?raw=true)

The wonderful folks behind Inertia came up with __PingCRM__, a demo app that illustrates how to use Inertia with React, Vue, and more! Over the course of a few days, I translated the existing Vue/Laravel implementation into an Elm/Laravel one. 

It includes patterns for handling unexpected HTTP responses from the server, so you can give users the best feedback possible! 

Here's [the full source code](https://github.com/ryan-haskell/pingcrm-elm), it's built with the `elm-inertia` Elm and NPM packages.


## **Disclaimer**

While I was implementing the [@ryan-haskell/pingcrm-elm](https://github.com/ryan-haskell/pingcrm-elm) app, I noticed some of my code could be generally useful for anyone using Inertia. Rather than keeping my code private, I extracted out and documented the parts that I thought would be helpful for others.

I encourage you to use this package to create your own Elm projects with your Inertia backend servers. Please feel welcome to modify my open source code if there are any features you would like to add.

Although my code is free to take, and the package is free to use, it __does not come with any promise for future maintenance__. This is a small gift from me to the Elm community, and there are many other cool Elm things I want to spend my time on after sharing it.

If you are personally interested in improving this project, or want to integrate this into a project at work, I'm happy to chat. Please reach out to me on the [Elm Slack](https://elm-lang.org/community/slack) (`@ryan`).