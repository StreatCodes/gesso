# Gesso

A Zig UI framework that renders a tree of elements to the screen using SDL3. It accepts an HTML like description of the UI in a tree structure, and simply renders it. The intent is for Gesso to serve as the rendering backend for higher-level languages that express UI with a nicer syntax.

## Run

```sh
zig build run
```

## Architecture

The UI is rendered with the following concepts, in order.
 - Parser - Takes in HTML like text and produces a `Document` or `Element`s and `Text`s in a tree. e.g. `<block><text>Hello, world!</text></block>`
 - Tree - Takes the `Document` tree and produces a `Tree` of `Node`s. e.g. a `Text` node includes all the information required to render some text.
 - Layout - Takes the `Tree` and produces a flat slice of `Box`s, essentially a quad with all positional information required to render.
 - Renderer - Take the slice of `Box`'s and draws them to the screen with SDL3's built in renderer.
