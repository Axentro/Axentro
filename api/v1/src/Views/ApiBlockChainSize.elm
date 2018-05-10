module Views.ApiBlockChainSize exposing (..)

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


pageApiBlockChainSize : Model -> List (Html Msg)
pageApiBlockChainSize model =
    let
        description =
            div [] [ Html.text "This retrieves the total length of the blockchain" ]

        ex =
            """{"status":"success","result":{"size":1}}"""
    in
        [ br [] []
        , Grid.row []
            [ apiLeftNav ApiBlockchainSize
            , Grid.col [ Col.md9 ]
                [ documentation ApiBlockchainSize model.apiUrlB3 model.apiResponse "Blockchain Size" description "GET" "api/v1/blockchain/size" Nothing Nothing "curl -X GET -H 'Content-Type: application/json' http://testnet.sushichain.io:3000/api/v1/blockchain/size" ex model.error
                ]
            ]
        ]
