import Check exposing (..)
import Check.Investigator exposing (..)
import Check.Runner.Browser exposing (display)
import Result exposing (Result)

reverse : List a -> List a
reverse ls = List.reverse ls

claim_reverse_twice_yields_original =
  claim
    "Reversing a list twice yields the original list"
  `that`
    (\list -> reverse (reverse list))
  `is`
    (identity)
  `for`
    list int


claim_reverse_does_not_modify_length =
  claim
    "Reversing a list does not modify its length"
  `that`
    (\list -> List.length (reverse list))
  `is`
    (\list -> List.length list)
  `for`
    list int


suite_reverse =
  suite "reverse list Suite"
    [ claim_reverse_twice_yields_original
    , claim_reverse_does_not_modify_length 
    ]

result = quickCheck suite_reverse

main = display result

