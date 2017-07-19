**0.17 and later users please see [elm-community/elm-check](https://github.com/elm-community/elm-check/).** This fork is no longer maintained.

# Property Based Testing in Elm with elm-check

Traditional unit-testing consists in asserting that certain inputs yield certain outputs. Property-based testing makes
claims relating input and output. These claims can then be automatically tested over as many randomly-generated inputs
as desired. If a failing input is found, it can be "shrunk" to compute a minimal failing case which is more
representative of the bug. The goal of `elm-check` is to automate this process.

This library can replace many unit tests, but it cannot test asynchronous, UI, or end-to-end functionality.

## Quick-Start Guide

Suppose you wanted to test `List.reverse`. A correct implementation will obey a number of properties (or assertions),
*regardless of the list being reversed*, including:

1. Reversing a list twice yields the original list.
2. Reversing does not modify the length of a list.

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
        identity
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
isn't complicated. A test claims that, for any input `x`, `actual x == expected x`.
4. `for <Producer>` An `Producer` is basically a way to randomly create values for the inputs to the functions. So
rather than operating on a single example, like unit testing, it can test that a relationship holds for many values.
There's an entire module full of `Producer`s so you can test almost anything.

We also group our two claims into a suite. Suites can be nested within other suites as deep as you like, so they're
useful for organizing tests of many features or modules.

Once you've built your claims, verifying them is easy:

```elm
evidence : Evidence
evidence = quickCheck myClaims
```

`quickCheck` will take either a single claim or a suite of claims and will run 100 checks on each claim to attempt to
disprove each claim. `quickCheck` will then return a descriptive result of the checks performed, in the `Evidence` type.

You can dive into these results if you like, but the simplest way to know "did my tests pass" is to use
[elm-test](http://package.elm-lang.org/packages/deadfoxygrandpa/elm-test/latest).

```elm
main = ElmTest.elementRunner (Check.Test.evidenceToTest evidence)
```

Running the page in `elm reactor` will inform you that all tests have passed. (You can find the complete code under
`examples`.)

## Debugging a Failing Claim

Suppose you start with a number `x`. Mathematically, if you multiply by another number `y`, and then divide by `y`, you
should be left with `x`. You would make this claim as follows:

```elm
myClaims =
  claim
    "Multiplication and division are inverse operations"
  `that`
    (\(x, y) -> x * y / y)
  `is`
    (\(x, y) -> x)
  `for`
    tuple (float, float)
```

Note that we're using the `tuple` producer because the functions we pass must take exactly one argument. If you put
this into the program above, you'd get:

> Multiplication and division are inverse operations: FAILED.  
> On check 23, found counterexample: (0,0)  
> Expected:  0  
> But It Was: NaN

This result shows that `elm-check` has found a counter example, namely `(0,0)` which falsifies the claim. This is
obviously true because division by 0 is undefined, hence the `NaN` value.

We can easily exclude zero by filtering the producer. Change the last line to:

```elm
filter (\(x, y) -> y /= 0) (tuple (float, float))
```

This function (in `Check.Producer`) will only use values that meet our criteria (not being equal to zero). This is
preferable to changing the expected and actual functions because it's simpler, and it doesn't reduce the number of
inputs we try.

Now we get a different error.

> Multiplication and division are inverse operations, if zero is omitted: FAILED.  
> On check 20, found counterexample: (0.00019869294196802492,0.0001670854544888915)  
> Expected:   0.00019869294196802492  
> But It Was: 0.00019869294196802494

Floating point arithmetic strikes again! Notice that the expect and the actual values only differ by a tiny amount.

Instead of claiming equality, we want to claim that the two values are near to each other. In particular, we want to say
that the difference of these values is very close to zero. Rather than supplying expected and actual, we will supply a
function that we expect to always be true.

```elm
myClaims : Claim
myClaims =
  claim
    "Multiplication and division are near inverse operations"
  `true`
    (\(x, y) -> abs ((x * y / y) - x) < 1e-6)
  `for`
    filter (\(x, y) -> y /= 0) (tuple (float, float))
```

The test now passes. This gives us confidence that multiplication and division are very nearly inverses, for any pair of
floats where the second one isn't zero.

## Debugging Compiler Errors

The DSL can give difficult error messages. Ensure that each claim uses one of these three patterns:

1. claim - (string) - that - (actual) - is - (expected) - for - (producer)
2. claim - (string) - true - (predicate) - for - (producer)
3. claim - (string) - false - (predicate) - for - (producer)

Ensure that each of these words except `claim` is surrounded by backticks.

If you're putting main claims together in a suite, ensure that you have commas between each claim.

Ensure that the two functions you pass have the same type. Ensure the input type matches the producer. Ensure the
output type is something equatable -- functions aren't, so be sure you fully apply them.

## Writing Good Properties

It can be difficult to write claims about a system, especially if it's not simple mathematics or a data structure.

[Jessica Kerr](https://vimeo.com/106759186) suggests writing "a box around the API". Rather than specifying an expected
value exactly, you should try to indicate a range in which it can reasonably fall.

## Shrinking

You may have noticed in the division example that the second pair of failing values were both very close to zero. This
is because of a process called *shrinking*, which in the case of floats, happens to bring them closer to zero. It makes
lists, strings, and most other things smaller.

Here's how it works, when `elm-check` encounters a failing test, it has strategies to shrink the input that caused the
failure. If any of *those* inputs cause a failure, it tries to shrink them in turn, until it has found a minimal failing
test case. Small examples of failure tend to be much more helpful for debugging.

Here's the thing: all of this happens automatically. You get smaller, easier-to-understand counterexamples, for free.

## Customization

We used the `quickCheck` function above to run our tests. There is also `check`, which allows you to supply a random seed
and specify the number of tests to run per claim, in case you think 100 is insufficient. More tests increase the
likelihood of finding obscure bugs, but take longer.

Once again, the easiest way to view the results of your tests is `Check.Test.evidenceToTest`. The resulting value can be
used with any of `elm-test`'s runners, including on the console for CI builds.

If you *really* want to explore the results of your tests, the `Evidence` type is fully exposed and includes a large
amount of information.

You may want to test a function whose input does not have an producer available. If possible, convert or map over an
existing producer to obtain the one you need. If necessary, you can write your own because the definition of `Producer`
is exported. You'll need to dive into `elm-shrink`, as well and the `Random` module.

## Upgrading from 2.x

The `Investigator` type has been renamed `Producer`. You should do a find-and-replace. If you defined your own
investigators, you'll need to use the type alias directly. So `investigator generator shrinker` should become `Producer
generator shrinker`. `keepIf` and `dropIf` have been changed to `filter`. `void` is now `unit`.

The arguments to `check` have been reordered so that the `Claim` is last.

If you relied on `claimN`, `claimNTrue`, and so on, you will need to rewrite your tests in the DSL. If you used the DSL
in `Check.Test`, you will need to rewrite your tests using the main DSL, and then use `Check.Test.evidenceToTest` for
Integration with `elm-test`.
