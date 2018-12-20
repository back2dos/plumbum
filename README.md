# Plumbum [![Build Status](https://travis-ci.org/back2dos/plumbum.svg?branch=master)](https://travis-ci.org/back2dos/plumbum)

<img src="https://raw.githubusercontent.com/back2dos/plumbum/master/pb.png" height=100>

This library offers a mechanism for organizing the internal plumbing of an application into distinct scopes, which are:

- geared towards declarative syntax
- immutable (may hold mutable values, but will not change themselves)
- lazy (at least by default)
- reasonably well guarded against cyclic references

## Anatomy of a scope

### Dependencies

Every scope can define it's external dependencies with a special variable:

```haxe
class Button {
  var dependencies:{
    var enabled:Bool;
    var label:String;
    function onclick():Void;
  }
}
```

These dependencies will be used as the single constructor argument and will be stored into separate fields. You may refer to the `enabled` field as both `enabled` or `dependencies.enabled`.

#### Optional Dependencies

Dependencies can be made optional by providing a default value/implementation.

```haxe
class Button {
  var dependencies:{
    var enabled:Bool = true;
    var label:String;
    function onclick():Void {
      trace('clicked!');
    }
  }
}

//usage: 
new Button({ label: 'Hello!' });
```

### Declarations

A scope may have three kinds of declarations:

#### Methods

Methods work as they do in ordinary classes.

#### Properties

Scopes may have computed properties with `(get, set)` or `(get, never)` as access (without `@:isVar`). Everything else is rejected.

#### Variables

Variables must have a type and an initialization expression. Plumbum forces you to order variables in such a manner that you cannot refer to variables further below. The main goal is to avoid cyclic definitions. You can tag the scope as `@:lenient` to lift this constraints.

All variables are actually lazy, meaning if they are not accessed, the initialization expression is never evaluated. This allows deferring work and also helps facilitate the lenient mode to some degree. If you wind up building a cycle this way, you will get a runtime exception saying 'circular lazyness' in debug mode and a stack overflow for release builds.

The restrictions may be tightened in the future.

### Going Imperative

You may declare a constructor with an empty argument list. The code in the constructor body is run after the scope is properly set up. You can do anything you want. So try to be civil ;)

### Static members

Anything static is passed on to the compiler unmodified. Declarations cannot refer to static members directly (this is a temporary implementation limitation rather than a design decision).
