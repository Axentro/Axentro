module Views.Common exposing (..)

import Html exposing (..)
import Messages exposing (Msg)


title : Html Msg
title =
    h1 [] [ text "Kajiki - SushiChain Wallet" ]
