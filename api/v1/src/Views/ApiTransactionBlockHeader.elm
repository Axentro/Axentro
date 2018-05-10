module Views.ApiTransactionBlockHeader exposing (..)

import Html.Events exposing (onClick, onInput)
import Json.PrettyPrint
import Views.TableHelper exposing (docTable)
import Views.ApiLeftNav exposing (apiLeftNav)
import Html exposing (..)
import Html.Attributes exposing (..)
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
import Bootstrap.Alert as Alert
import Bootstrap.Form.Textarea as TextArea
import Bootstrap.Form.Input as Input
import Messages exposing (Method(GET), Msg(..), Page(..))
import Views.ApiDocumentationHelper exposing (documentation)


pageApiTransactionBlockHeader : Model -> List (Html Msg)
pageApiTransactionBlockHeader model =
    let
        description =
            div [] [ Html.text "This retrieves the block header containing the specified transaction id as Json" ]

        ex = """{"status":"success","result":{"index":1,"nonce":3981483406659451763,"prev_hash":"5396e18efa80a8e891c417fff862d7cad171465e65bc4b4e5e1c1c3ab0aeb88f","merkle_tree_root":"55aec377396d17730181d4400931fd97ce59e4dd"}}"""
    in
        [ br [] []
        , Grid.row []
            [ apiLeftNav ApiTransactionBlockHeader
            , Grid.col [ Col.md9 ]
                [ documentation ApiTransactionBlockHeader model.apiUrlT3 Nothing model.apiResponse "Transaction Block Header" description "GET" "api/v1/transaction/{:id}/block/header" Nothing Nothing "curl -X GET -H 'Content-Type: application/json' http://testnet.sushichain.io:3000/api/v1/transaction/{:id}/block/header" ex model.error
                ]
            ]
        ]
