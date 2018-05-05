module Views.ApiBlockChainHeader exposing (..)

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
import Messages exposing (Msg(..), Page(..))
import Views.ApiLeftNav exposing (apiLeftNav)

pageApiBlockChainHeader : Model -> List (Html Msg)
pageApiBlockChainHeader model =
    [ h3 [] [ text "v1 Blockchain Header" ]
    , Grid.row []
        [ apiLeftNav ApiBlockchainHeader
        , Grid.col [ Col.md9 ] [ text "main doc" ]
        ]
    ]
