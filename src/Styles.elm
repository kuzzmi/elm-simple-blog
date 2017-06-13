module Styles exposing (Styles(..), Variations(..), stylesheet)

import Style exposing (..)
import Style.Font as Font
import Style.Color as Color
import Style.Border as Border
import Color


type Styles
    = None
    | Main
    | PostTitle
    | Logo
    | NavOption
    | TagStyle
    | ButtonStyle
    | TextInputStyle
    | LabelStyle
    | ErrorStyle
    | Footer
    | FooterLogo
    | FooterHeart


type Variations
    = Active
    | Link


darkGrey : Color.Color
darkGrey =
    Color.rgb 57 57 57


lightGrey : Color.Color
lightGrey =
    Color.rgb 204 204 204


orange : Color.Color
orange =
    Color.rgb 255 131 0


stylesheet : StyleSheet Styles Variations
stylesheet =
    Style.stylesheet
        [ style None []
        , style Main
            [ Font.typeface [ "Overpass", "monospace" ]
            , Font.lineHeight 2
            , Color.text darkGrey
            ]
        , style PostTitle
            [ Font.size 32
            , Font.weight 700
            , Color.text darkGrey
            , variation Link
                [ Style.cursor "pointer"
                , hover
                    [ Font.underline
                    ]
                ]
            ]
        , style Logo
            [ Font.size 26
            , Font.weight 600
            , Color.text orange
            , Style.cursor "pointer"
            , hover
                [ Font.underline
                ]
            ]
        , style NavOption
            [ Font.size 26
            , Font.weight 600
            , Color.text darkGrey
            , Style.cursor "pointer"
            , hover
                [ Font.underline
                ]
            , variation Active
                [ Color.text Color.white
                , Color.background darkGrey
                ]
            ]
        , style TagStyle
            [ Color.text (Color.rgb 120 120 120)
            , Color.background (Color.rgb 242 242 242)
            , Style.cursor "pointer"
            , hover
                [ Color.text orange
                , Font.underline
                ]
            ]
        , style ButtonStyle
            [ Color.background darkGrey
            , Color.text Color.white
            , Style.cursor "pointer"
            , hover
                [ Color.text orange
                ]
            ]
        , style LabelStyle
            [ Color.border darkGrey
            , Font.weight 600
            ]
        , style ErrorStyle
            [ Color.text Color.white
            , Color.background Color.red
            , Style.cursor "default"
            ]
        , style TextInputStyle
            [ Font.typeface [ "Overpass", "monospace" ]
            , Font.size 16
            , Font.lineHeight 2
            , Color.border darkGrey
            , Border.bottom 1
            , Border.solid
            ]
        , style Footer []
        , style FooterHeart
            [ Color.text (Color.rgb 255 0 0)
            ]
        , style FooterLogo
            [ Color.text orange
            , hover
                [ Font.underline
                ]
            ]
        ]
