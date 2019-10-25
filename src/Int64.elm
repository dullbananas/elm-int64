module Int64 exposing
    ( Int64(..), fromInt, fromParts
    , add, subtract
    , and, or, xor, complement
    , shiftLeftBy, shiftRightZfBy, rotateLeftBy, rotateRightBy
    , toSignedString, toUnsignedString
    , decoder, encoder
    , toHex, toByteValues, toBits, toBitString
    )

{-| An efficient 64-bit unsigned integer

Bitwise operators in javascript can only use 32 bits. Sometimes, external protocols use 64-bit integers. This package implementes such integers with "correct" overflow behavior.

This is a low-level package focussed on speed.

@docs Int64, fromInt, fromParts


## Arithmetic

@docs add, subtract


## Bitwise

@docs and, or, xor, complement
@docs shiftLeftBy, shiftRightZfBy, rotateLeftBy, rotateRightBy


## Conversion

@docs toSignedString, toUnsignedString
@docs decoder, encoder
@docs toHex, toByteValues, toBits, toBitString

-}

import Bitwise
import Bytes exposing (Endianness(..))
import Bytes.Decode as Decode exposing (Decoder)
import Bytes.Encode as Encode exposing (Encoder)
import Hex


{-| Convert a `Int` to `Int64`.

This is guaranteed to work for integers in the safe JS range.

    fromInt 42
        |> toSignedString
        --> "42"

-}
fromInt : Int -> Int64
fromInt raw =
    if raw < 0 then
        let
            lower =
                raw
                    |> abs
                    |> Bitwise.complement
                    |> Bitwise.shiftRightZfBy 0
                    |> (+) 1

            upper =
                if lower > 0xFFFFFFFF then
                    raw // (2 ^ 32) - 1 + 1

                else
                    raw // (2 ^ 32) - 1
        in
        Int64
            (upper |> Bitwise.shiftRightZfBy 0)
            (lower |> Bitwise.shiftRightZfBy 0)

    else if raw > 0xFFFFFFFF then
        Int64 (raw - Bitwise.shiftRightZfBy 0 raw - 0xFFFFFFFF) (Bitwise.shiftRightZfBy 0 raw)

    else
        Int64 0 raw


{-| Give two integers, corresponding to the upper and lower 32 bits

    fromParts 4 2
        |> toHex
        --> "0000000400000002"

-}
fromParts : Int -> Int -> Int64
fromParts =
    Int64


{-| The individual bits

Bits are given in big-endian order.

    toBits (fromInt 10)
        --> [False,False,False,False,False,False,False,False,False,False,False,False,False,False,False,False,False,False,False,False,False,False,False,False,False,False,False,False,False,False,False,False,False,False,False,False,False,False,False,False,False,False,False,False,False,False,False,False,False,False,False,False,False,False,False,False,False,False,False,False,True,False,True,False]

-}
toBits : Int64 -> List Bool
toBits (Int64 upper lower) =
    bits32 upper ++ bits32 lower


{-| Bits as a string

    toBitString (fromInt 42)
        --> "0000000000000000000000000000000000000000000000000000000000101010"

-}
toBitString : Int64 -> String
toBitString input =
    toBits input
        |> List.foldr
            (\b accum ->
                case b of
                    True ->
                        String.cons '1' accum

                    False ->
                        String.cons '0' accum
            )
            ""


bits32 : Int -> List Bool
bits32 value =
    bits32Help 32 value []


bits32Help n remaining accum =
    if n > 0 then
        let
            new =
                Bitwise.and 1 remaining == 1
        in
        bits32Help (n - 1) (Bitwise.shiftRightZfBy 1 remaining) (new :: accum)

    else
        accum


{-| Interpret a `Int64` as an unsigned integer, and give its string representation

    toSignedString (fromInt 10)
        --> "10"

    toSignedString (fromInt -10)
        --> "-10"

-}
toSignedString : Int64 -> String
toSignedString ((Int64 origUpper origLower) as input) =
    let
        isPositive =
            Bitwise.and (Bitwise.shiftLeftBy 31 1) upper /= 0

        (Int64 upper lower) =
            complement input

        newLower =
            lower + 1

        newUpper =
            if newLower > 0xFFFFFFFF then
                upper

            else
                upper
    in
    if isPositive then
        toUnsignedStringHelp origUpper origLower ""

    else
        "-" ++ toUnsignedStringHelp newUpper newLower ""


{-| Interpret a `Int64` as an unsigned integer, and give its string representation

    toUnsignedString (fromInt 10)
        --> "10"

    toUnsignedString (fromInt -10)
        --> "18446744073709551606"

-}
toUnsignedString : Int64 -> String
toUnsignedString ((Int64 upper lower) as input) =
    toUnsignedStringHelp upper lower ""


toUnsignedStringHelp upper lower accum =
    let
        digit =
            ((upper |> modBy 10) * (2 ^ 32) + lower) |> modBy 10

        nextUpper =
            upper // 10

        nextLower =
            ((upper |> modBy 10) * (2 ^ 32) + lower) // 10
    in
    if lower < 10 && upper == 0 then
        String.cons (Char.fromCode (digit + 48)) accum

    else
        toUnsignedStringHelp (Bitwise.shiftRightZfBy 0 nextUpper) (Bitwise.shiftRightZfBy 0 nextLower) (String.cons (Char.fromCode (digit + 48)) accum)


{-| Int64 stores two times 32 bits in two integers.

    -- zero
    UnsignedInt 0 0

    -- maximum value
    Int64 0xFFFFFFFF 0xFFFFFFFF

Note that technically

  - you can create an integer with a higher value, e.g. `0xFFFFFFFF + 42`
  - you can use negative numbers

All operations will convert numbers to their unsigned 32-bit operation.

-}
type Int64
    = Int64 Int Int


{-| Bitwise and
-}
and : Int64 -> Int64 -> Int64
and (Int64 a b) (Int64 p q) =
    Int64 (Bitwise.and a p) (Bitwise.and b q)


{-| Bitwise complement
-}
complement : Int64 -> Int64
complement (Int64 a b) =
    Int64
        (Bitwise.complement a |> Bitwise.shiftRightZfBy 0)
        (Bitwise.complement b |> Bitwise.shiftRightZfBy 0)


{-| Bitwise or
-}
or : Int64 -> Int64 -> Int64
or (Int64 a b) (Int64 p q) =
    Int64 (Bitwise.or a p) (Bitwise.or b q)


{-| Bitwise xor
-}
xor : Int64 -> Int64 -> Int64
xor (Int64 a b) (Int64 p q) =
    Int64 (Bitwise.xor a p) (Bitwise.xor b q)


{-| 64-bit addition, with correct overflow

    (fromParts 0xFFFFFFFF 0xFFFFFFFF)
        |> Int64.add (Int64.fromInt 1)
        |> Int64.toUnsignedString
        --> "0"

-}
add : Int64 -> Int64 -> Int64
add (Int64 a b) (Int64 p q) =
    let
        lower =
            Bitwise.shiftRightZfBy 0 b + Bitwise.shiftRightZfBy 0 q

        higher =
            Bitwise.shiftRightZfBy 0 a + Bitwise.shiftRightZfBy 0 p
    in
    -- check for overflow in the lower bits
    if lower > 0xFFFFFFFF then
        Int64 (Bitwise.shiftRightZfBy 0 (higher + 1)) (Bitwise.shiftRightZfBy 0 lower)

    else
        Int64 (Bitwise.shiftRightZfBy 0 higher) (Bitwise.shiftRightZfBy 0 lower)


{-| 64-bit subtraction, with correct overflow

    -- equivalent to `0 - 1`
    Int64.subtract  (Int64.fromInt 0) (Int64.fromInt 1)
        |> Int64.toUnsignedString
        --> "18446744073709551615"


    -- equivalent to `1 - 0`
    Int64.subtract  (Int64.fromInt 1) (Int64.fromInt 0)
        |> Int64.toUnsignedString
        --> "1"

-}
subtract : Int64 -> Int64 -> Int64
subtract (Int64 a b) (Int64 p q) =
    let
        lower =
            Bitwise.shiftRightZfBy 0 b - Bitwise.shiftRightZfBy 0 q

        higher =
            Bitwise.shiftRightZfBy 0 a - Bitwise.shiftRightZfBy 0 p
    in
    -- check for overflow in the lower bits
    if lower < 0 then
        Int64 (Bitwise.shiftRightZfBy 0 (higher - 1)) (Bitwise.shiftRightZfBy 0 lower)

    else
        Int64 (Bitwise.shiftRightZfBy 0 higher) (Bitwise.shiftRightZfBy 0 lower)


{-| Left bitwise shift, typically written `<<`
-}
shiftLeftBy : Int -> Int64 -> Int64
shiftLeftBy n (Int64 higher lower) =
    if n > 32 then
        let
            carry =
                Bitwise.shiftLeftBy n lower
        in
        Int64 carry 0

    else
        let
            carry =
                Bitwise.shiftRightZfBy (32 - n) lower

            newHigher =
                higher
                    |> Bitwise.shiftLeftBy n
                    |> Bitwise.or carry
        in
        Int64 newHigher (Bitwise.shiftLeftBy n lower)


{-| Right bitwise shift, typically written `>>` (but `>>>` in JavaScript)
-}
shiftRightZfBy : Int -> Int64 -> Int64
shiftRightZfBy n (Int64 higher lower) =
    if n > 32 then
        Int64 0 (Bitwise.shiftRightZfBy n higher)

    else
        let
            carry =
                Bitwise.shiftLeftBy (32 - n) higher

            newLower =
                lower
                    |> Bitwise.shiftRightZfBy n
                    |> Bitwise.or carry
                    |> Bitwise.shiftRightZfBy 0
        in
        Int64 (Bitwise.shiftRightZfBy n higher) newLower


{-| Left bitwise rotation

    (Int64 0xDEADBEAF 0xBAAAAAAD)
        |> Int64.rotateLeftBy 16
        |> Int64.toHex
        --> "beafbaaaaaaddead"

-}
rotateLeftBy : Int -> Int64 -> Int64
rotateLeftBy n_ ((Int64 higher lower) as i) =
    let
        n =
            n_ |> modBy 64
    in
    if n == 32 then
        Int64 lower higher

    else if n == 0 then
        Int64 higher lower

    else if n >= 32 then
        let
            -- guaranteed m <= 32
            m =
                64 - n

            carry1 =
                Bitwise.shiftLeftBy (n - 32) lower

            carry2 =
                Bitwise.shiftRightZfBy (32 - (n - 32)) higher

            carry3 =
                Bitwise.shiftLeftBy (n - 32) higher

            carry4 =
                Bitwise.shiftRightZfBy (32 - (n - 32)) lower
        in
        Int64 (Bitwise.or carry1 carry2) (Bitwise.or carry3 carry4)

    else
        -- n <= 32, m > 32
        let
            carry1 =
                Bitwise.shiftLeftBy n lower

            carry2 =
                Bitwise.shiftRightZfBy (32 - n) higher

            carry3 =
                Bitwise.shiftLeftBy n higher

            carry4 =
                Bitwise.shiftRightZfBy (32 - n) lower
        in
        Int64 (Bitwise.or carry3 carry4) (Bitwise.or carry1 carry2)


{-| Right bitwise rotation

    (Int64 0xDEADBEAF 0xBAAAAAAD)
        |> Int64.rotateRightBy 16
        |> Int64.toHex
        --> "aaaddeadbeafbaaa"

-}
rotateRightBy : Int -> Int64 -> Int64
rotateRightBy n_ ((Int64 higher lower) as i) =
    let
        n =
            n_ |> modBy 64
    in
    if n == 32 then
        Int64 lower higher

    else if n == 0 then
        Int64 higher lower

    else if n > 32 then
        let
            -- guaranteed m <= 32
            m =
                64 - n

            carry =
                Bitwise.shiftRightZfBy (32 - m) lower

            p1 =
                higher
                    |> Bitwise.shiftLeftBy m
                    |> Bitwise.or carry

            p2 =
                Bitwise.shiftLeftBy m lower

            q1 =
                0

            q2 =
                Bitwise.shiftRightZfBy n higher
        in
        Int64 (Bitwise.or p1 q1) (Bitwise.or p2 q2)

    else
        let
            -- guaranteed n <= 32, m > 32
            m =
                64 - n

            p1 =
                Bitwise.shiftLeftBy m lower

            p2 =
                0

            carry =
                Bitwise.shiftLeftBy (32 - n) higher

            q1 =
                Bitwise.shiftRightZfBy n higher

            q2 =
                lower
                    |> Bitwise.shiftRightZfBy n
                    |> Bitwise.or carry
        in
        Int64 (Bitwise.or p1 q1) (Bitwise.or p2 q2)



-- Bytes


{-| A `elm/bytes` Decoder for `Int64`
-}
decoder : Endianness -> Decoder Int64
decoder endianness =
    case endianness of
        BE ->
            Decode.map2 Int64
                (Decode.unsignedInt32 BE)
                (Decode.unsignedInt32 BE)

        LE ->
            Decode.map2 (\lower higher -> Int64 higher lower)
                (Decode.unsignedInt32 LE)
                (Decode.unsignedInt32 LE)


{-| A `elm/bytes` Encoder for `Int64`
-}
encoder : Endianness -> Int64 -> Encoder
encoder endianness (Int64 higher lower) =
    case endianness of
        BE ->
            Encode.sequence
                [ Encode.unsignedInt32 BE higher
                , Encode.unsignedInt32 BE lower
                ]

        LE ->
            Encode.sequence
                [ Encode.unsignedInt32 LE lower
                , Encode.unsignedInt32 LE higher
                ]


{-| Convert a `Int64` to a hexadecimal string

    toHex (fromInt (256 - 1))
        -->  "00000000000000ff"

-}
toHex : Int64 -> String
toHex (Int64 higher lower) =
    let
        high =
            higher
                |> Bitwise.shiftRightZfBy 0
                |> Hex.toString
                |> String.padLeft 8 '0'

        low =
            lower
                |> Bitwise.shiftRightZfBy 0
                |> Hex.toString
                |> String.padLeft 8 '0'
    in
    high ++ low


{-| Convert an `Int64` to its 8 byte values in big-endian order

    toByteValues  (fromInt 0xDEADBEAF)
        --> [0,0,0,0,222,173,190,175]

-}
toByteValues : Int64 -> List Int
toByteValues (Int64 higher lower) =
    wordToBytes higher ++ wordToBytes lower


wordToBytes : Int -> List Int
wordToBytes int =
    [ int |> Bitwise.shiftRightZfBy 0x18 |> Bitwise.and 0xFF
    , int |> Bitwise.shiftRightZfBy 0x10 |> Bitwise.and 0xFF
    , int |> Bitwise.shiftRightZfBy 0x08 |> Bitwise.and 0xFF
    , int |> Bitwise.and 0xFF
    ]
