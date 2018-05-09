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
import Views.ApiDocumentationHelper exposing (documentation)
import Views.ApiLeftNav exposing (apiLeftNav)


pageApiBlockChainHeader : Model -> List (Html Msg)
pageApiBlockChainHeader model =
    let
        description =
            div [] [ Html.text "This retrieves the headers of the entire blockchain as Json" ]

        ex =
            """{"status":"success","result":[{"index":0,"nonce":0,"prev_hash":"genesis","merkle_tree_root":""}]}"""
    in
        [ br [] []
        , Grid.row []
            [ apiLeftNav ApiBlockchainHeader
            , Grid.col [ Col.md9 ]
                [ documentation ApiBlockchainHeader model.apiUrlB2 model.apiResponse "Blockchain Header" description "GET" "api/v1/blockchain/header" "curl -X GET -H 'Content-Type: application/json' http://testnet.sushichain.io:3000/api/v1/blockchain/header" ex model.error
                ]
            ]
        ]
