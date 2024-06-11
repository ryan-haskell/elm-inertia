# Inertia.js Elm Adapter

The Elm adapter for Inertia.js.


## Table of contents

- [Installation](#installation)
- [Using the Module](#using-the-module)
- [Using the CLI](#using-the-cli)
  - [elm-inertia init](#elm-inertia-init)
  - [elm-inertia add](#elm-inertia-add)
  - [elm-inertia generate](#elm-inertia-generate)
- [Additional resources](#additional-resources)

## Installation

```
npm install -S elm-inertia
```

**Note:** This works alongside the companion [Elm Package](https://package.elm-lang.org/packages/ryan-haskell/elm-inertia/latest).


## Using the Module

Rather than initializing your Elm application the standard way, you'll want to use this package's `createInertiaApp` function.

This handles wiring up the required ports, reading the `data-page` attribute, and the other important Inertia things.

### Example with Vite

1. Install Vite dependencies

```
npm i -D vite vite-plugin-elm-watch
```

2. Ensure Vite is configured to handle `*.elm` files

```js
// vite.config.js

import { defineConfig } from 'vite'
import elm from 'vite-plugin-elm-watch'

export default defineConfig({
  plugins: [ elm() ]
})
```

3. Initialize your app using `createInertiaApp`

```js
// src/main.js

import { createInertiaApp } from 'elm-inertia'
import Main from './src/Main.elm'

let app = createInertiaApp({
  node: document.getElementById('app'),
  init: Main.init,
  flags: {
    window: {
      width: window.innerWidth,
      height: window.innerHeight,
    }
  },
})

// Register ports with `app.ports`...
```

## Using the CLI

This package also comes with a few CLI commands to help you scaffold out new Inertia pages.

**Note:** The CLI assumes you are following the conventions outlined in our example applications.

### elm-inertia init

Creates a new elm-inertia frontend with everything you need.

```sh
elm-inertia init
```

### elm-inertia add

Create a new page in the `src/Pages` folder.

```sh
elm-inertia add Organizations/Edit
```

For convenience, this also runs `generate` after the page is created.



### elm-inertia generate

Regenerate your `src/Pages.elm` file. This file connects all pages in the `src/Pages` folder to your application.

```
elm-inertia generate
```

### **How do I delete pages?** 

To remove a page, simply delete the file, and rerun the `elm-inertia generate` command!

## Additional resources

- [PingCRM](https://github.com/ryan-haskell/pingcrm-elm) - Complete application using Elm with Laravel
- [Source code](https://github.com/ryan-haskell/elm-inertia) - Code for the Elm package and NPM module