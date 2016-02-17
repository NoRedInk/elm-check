# Property Based Testing in Elm with elm-check

Traditional unit-testing consists in asserting that certain inputs yield certain outputs. Property-based testing makes
claims relating input and output. These claims can then be automatically tested over as many randomly-generated inputs
as desired. If a failing input is found, it can be "shrunk" to compute a minimal failing case which is more
representative of the bug. The goal of `elm-check` is to automate this process.

## Quick-Start Guide

Suppose you wanted to test `List.reverse`. A correct implementation will obey a number of properties, *regardless of the
list being reversed*, including:

1. Reversing a list twice yields the original list
2. Reversing does not modify the length of a list

You can make these claims in `elm-check` as follows:

```elm
myClaims : Claim
myClaims =
  suite "List Reverse"
    [ claim
        "Reversing a list twice yields the original list"
      `that`
        (\list -> reverse (reverse list))
      `is`
        (identity)
      `for`
        list int

    , claim
      "Reversing a list does not modify its length"
    `that`
      (\list -> length (reverse list))
    `is`
      (\list -> length list)
    `for`
      list int
    ]
```

As, you can see, `elm-check` defines a Domain-Specific Language (DSL) for writing claims. It may look odd at first, but
the code is actually very straightforward to work with.

> ***Straightforward?!*** It might help to review some language features being used. First, `suite` takes a string and a
> list, which forms most of the code. The list actually has only two items, the result of calling `claim` twice. (See
> the comma right before the second `claim`?)  Backticks indicate that a function is being called infix. `(\x -> thing x)`
> is an anonymous function.

Let's examine each component of a claim.

1. `claim <String>` This is the name of the test and is used when output is displayed, so make it descriptive.
2. `that <function>` This is the "actual" value, the result of the code or feature under test.
3. `is <function>` This is the "expected" value. Think of it like a control in a science experiment. It's the value that
isn't complicated. The actual and expected values should always be equal. The types of these two functions must be the
same.
4. `for <Investigator>` An `Investigator` is basically a way to randomly produce values for the inputs to the functions.
So rather than operating on a single example, like unit testing, it can test that a relationship holds for many values.
There's an entire module full of `Investigators` so you can test almost anything.

Once you've built your claims, verifying them is easy:

```elm
evidence : Evidence
evidence = quickCheck myClaims
```

`quickCheck` will take either a single claim or a suite of claims and will run 100 checks on each claim to attempt to
disprove each claim. `quickCheck` will then return a descriptive result of the checks performed, in the `Evidence` type.

You can dive into these results if you like, but the simplest way to know "did my tests pass" is to use
[elm-test](http://package.elm-lang.org/packages/deadfoxygrandpa/elm-test/latest/ElmTest).

```elm
main = ElmTest.elementRunner (Check.Test.evidenceToTest evidence)
```

TODO: insert image of passing tests

TODO: true and false claims


TODO: update everything below here

## Debugging a Failing Claim

Suppose we wanted to test that multiplication and division are inverse operations.

You would make this claim as follows:

```elm
claim_multiplication_division_inverse =
  claim
    "Multiplication and division are inverse operations"
  `that`
    (\(x, y) -> x * y / y)
  `is`
    (\(x, y) -> x)
  `for`
    tuple (float, float)
```

Now, if you run `quickCheck` on this claim and displayed it in the browser with `display`, you would get:

```
Multiplication and division are inverse operations FAILED after 1 check!
  - Counter example: (0,0)
  - Actual: NaN
  - Expected: 0
```

This result shows that `elm-check` has found a counter example, namely `(0,0)`
which falsifies the claim. This is obviously true because division by 0 is undefined, hence the `NaN` value.

We can solve this issue by adding this condition to our actual statement and modify it as follows:

```elm
claim_multiplication_division_inverse =
  claim
    "Multiplication and division are inverse operations"
  `that`
    (\(x, y) -> if y == 0 then x else x * y / y)
  `is`
    (\(x, y) -> x)
  `for`
    tuple (float, float)
```

So, we added the condition where if y is 0, we simply return x. Now, let's see
what `elm-check` gives us now if we run `quickCheck`.

```
Multiplication and division are inverse operations FAILED after 1 check!
  - Counter example: (0.0001073802195855836,0.00013967437556471545)
  - Actual: 0.00010738021958558358
  - Expected: 0.0001073802195855836
```

Uh-oh, a new counter example. So, we can see that the actual and the expected values are incredibly close. From their closeness we can easily infer that something went wrong in the rounding. This is exactly what has happened as this is a floating-point error.

An interesting thing to note is that the counter example found was incredibly close to the original one of `(0,0)`. How come? The `float` investigator has the ability to generate any random float. So, what has happened here?

Well, to do this let us look back at the original claim:

```elm
claim_multiplication_division_inverse =
  claim
    "Multiplication and division are inverse operations"
  `that`
    (\(x, y) -> x * y / y)
  `is`
    (\(x, y) -> x)
  `for`
    tuple (float, float)
```

And this time, instead of displaying the results with `display`, let us use the alternative `displayVerbose` function which gives more detail about the test results.

Now, we get this output:

```
Multiplication and division are inverse operations FAILED after 1 check!
  - Counter example: (0,0)
  - Actual: NaN
  - Expected: 0
  - Seed: State 879767458 1052200661
  - Number of shrinking operations performed: 4
  - Before shrinking:
    - Counter example: (-14.074540141521613,-18.307399754018384)
    - Actual: -14.074540141521611
    - Expected: -14.074540141521613
```

From here we can see that there are a "seed", a "number of shrinking operations performed" and a "before shrinking" fields. The "seed" is there in order to reproduce test results. The "shrinking" stuff relates to a feature that `elm-check` provides called "shrinking".

Shrinking is the idea of shrinking a test case to a minimal representation. In this case, the investigator `tuple (float, float)` has found the original counter example `(-14.074540141521613,-18.307399754018384)`. It has then taken this counter example and has searched for another counter example that is more minimal that still disproves the claim. It has then repeated this process until it finds no more minimal counter example that still disproves the claim, in this case, simply `(0,0)`. Intuitively, `(0,0)` is as minimal an input as it gets. Having such minimal inputs is key to diagnosing problem.

As we have seen, this simple claim has enabled us to diagnose two gotchas about division. Get used to this as it is very common for individual claims to encounter multiple problems with a system.


# Migrating from previous version (prior to Elm 0.15)

If you are currently using `elm-check` in Elm 0.14 code and would like to upgrade your tests to 0.15, you are going to like the new features and the simplified API.

### API CORE

First of all, `elm-check` does not deal simply with the `Random.Generator` type.

The api is centered around two functions:

```elm
claim : String -> (a -> b) -> (a -> b) -> Investigator a -> Claim

check : Claim -> Int -> Seed -> Evidence
```

and three types : `Claim`, `Investigator`, and `Evidence`.

- `Claim` is exactly analogous to `Property` in the previous version. The difference between `Claim` and `Property` is that `Claim` captures an expected vs actual relation. This means that `elm-check` can and does generate actual unit tests unlike previously where you could only deal in predicates. If you still want to define claims as predicates, you can use the `claimTrue` function or the `true` combinator if you are using the DSL.

- `Evidence` is the result type from running `check` on a claim or a suite of claims. This is analogous to `TestOutput` in the previous version. The difference is that now `Evidence` has additional information regarding shrinking.

- `Investigator` is the new kid in town. `elm-check` still relies on random generation provided by the `Random.Generator` type but, now, `elm-check` ships with shrinking out of the box and the `Investigator` type provides this.


```elm
type alias Investigator a =
  { generator : Random.Generator a
  , shrinker  : Shrinker a
  }

-- type alias Shrinker a = a -> List a
```


If you are familiar with Haskell's QuickCheck, then `Investigator` is exactly like `Arbitrary` in Haskell. From a user point of view, the main difference between using investigators and generators is that investigators are not as composable as generators. You can use operations such as `map`, `flatMap`, etc... on generators but not on investigators. This is due to shrinking. The shrinking algorithms used in `elm-check` can be found in [`elm-shrink`](https://github.com/TheSeamau5/elm-shrink), the companion library to `elm-check`.

But, in case you are worried about the composability, here's a concrete example of implementing your own investigator for a custom data type.

```elm
type alias Vector =
  { x : Float
  , y : Float
  , z : Float
  }

vector : Investigator Vector
vector =
  let
      shrinker {x,y,z} =
        Vector
          `Shrink.map`    shrink float x
          `Shrink.andMap` shrink float y
          `Shrink.andMap` shrink float z

      generator =
        Vector
          `Random.map`    random float
          `Random.andMap` random float
          `Random.andMap` random float
  in
      investigator generator shrinker
```

As you can see, you have to define separately a shrinker and a generator with the provided `map` and `andMap` functions. The `Random` functions come from [`elm-random-extra`](https://github.com/TheSeamau5/elm-random-extra) and the `Shrink` functions come from [`elm-shrink`](https://github.com/TheSeamau5/elm-shrink). Hopefully, the above code shows that the process is not overly complicated. Note that `Shrink.map` is just an alias for `List.map`. There is unfortunately no magical `map` function on shrinkers. So, you have to capture the data from the record you wish to shrink and then re-map it `Shrink.map`.


### Organizing Tests

One of the big features introduced in this version of `elm-check` is the ability to group claims together in suites using the `suite` function.

```elm
suite : String -> List Claim -> Claim
```


`suite` takes in a descriptive name for a suite and a list of claims and then outputs a claim. This makes suites themselves claims and thus arbitrarily nestable, which is key to represent your modules adequately.

For example, if you wanted to test the core `List` module, you could organize your claims as follows:

```elm
suite_list =
  suite "List Suite"
    [ suite "List Reverse"
      [ claim_reverse_reverse_identity
      , claim_reverse_preserves_length
      , ...
      ]
    , suite "List Append"
      [ claim_append_same_list_doubles_length
      , claim_append_lists_adds_length
      , claim_append_reverse_flip_reverse_append
      , ...
      ]
    , ...  
    ]
```

You can then simply call `check` or `quickCheck` on the entire suite as opposed to an individual claim as follows:

```elm
result = quickCheck suite_list
```

### DSL

The DSL was mentioned above but was not fully fleshed out. First of all, it is important to precise that the DSL provided by `elm-check` is strictly optional. The main function to make claims is `claim` and there are versions of this supporting multiple arities and you are most welcome to use them if you are not into DSLs (or just not into this one).


The DSL provided by `elm-check` is super simple and it is used to generate claims. This is how it looks:

```elm
claim_multiplication_division_inverse =
  claim
    "Multiplication and division are inverse operations"
  `that`
    (\(x, y) -> x * y / y)
  `is`
    (\(x, y) -> x)
  `for`
    tuple (float, float)
```

Without the DSL, this looks like:

```elm
claim_multiplication_division_inverse =
  claim
    "Multiplication and division are inverse operations"
    (\(x, y) -> x * y / y)
    (\(x, y) -> x)
    (tuple (float, float))

```

Simple, just remove those infix functions in the middle.

There are three flavors of these infix functions:

- claim - that - is - for
- claim - true - for
- claim - false - for

The last two are equivalent to using the `claimTrue` and `claimFalse` respectively. If we rewrote the example with `claim-true-for`, it would look like this:

```elm
claim_multiplication_division_inverse =
  claim
    "Multiplication and division are inverse operations"
  `true`
    (\(x, y) -> x * y / y == x)
  `for`
    tuple (float, float)
```

Which is exactly equivalent to:

```elm
claim_multiplication_division_inverse =
  claimTrue
    "Multiplication and division are inverse operations"
    (\(x, y) -> x * y / y == x)
    (tuple (float, float))
```

`claim-false-for` is exactly equivalent to `claim-true-for` but it flips the boolean.

An important thing to note about the DSL, these functions only work with `claim`. They don't even work with the multi-arity versions of `claim`. So, if you want to do have claims with multiple arguments, you have to use tuples directly. Functions like `claim2` or `claim3` use tuples behind the scenes, but the type system in Elm is such that I couldn't figure out how to introduce the DSL while still providing he ability to work with claims of arbitrary number of arguments. The examples above were picked purposefully to illustrate how this would be done.

