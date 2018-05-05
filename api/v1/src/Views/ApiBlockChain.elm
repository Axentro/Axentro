module Views.ApiBlockChain exposing (..)

import Views.ApiLeftNav exposing (apiLeftNav)
import Html exposing (..)
import Html.Attributes exposing (href)
import Models exposing (Model)
import Bootstrap.Navbar as Navbar
import Bootstrap.Grid as Grid
import Bootstrap.Grid.Col as Col
import Bootstrap.Card as Card
import Bootstrap.Card.Block as Block
import Bootstrap.Button as Button
import Bootstrap.ListGroup as Listgroup
import Bootstrap.Modal as Modal
import Bootstrap.Table as Table
import Messages exposing (Msg(..),Page(..))

pageApiBlockChain : Model -> List (Html Msg)
pageApiBlockChain model =
    [ h3 [] [ text "v1 Blockchain" ]
    , Grid.row []
        [ apiLeftNav ApiBlockchain
        , Grid.col [ Col.md9 ] [ text "main doc" ]
        ]
    ]
