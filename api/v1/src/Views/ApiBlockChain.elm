module Views.ApiBlockChain exposing (..)

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


pageApiBlockChain : Model -> List (Html Msg)
pageApiBlockChain model =
    let
        description =
            div [] [ Html.text "This retrieves the entire blockchain as Json" ]

        ex = """{"status":"success","result":[{"index":0,"transactions":[],"nonce":0,"prev_hash":"genesis","merkle_tree_root":""}]}"""
    in
        [ br [] []
        , Grid.row []
            [ apiLeftNav ApiBlockchain
            , Grid.col [ Col.md9 ]
                [ documentation ApiBlockchain model.apiUrlB1 model.apiResponse "Blockchain" description "GET" "api/v1/blockchain" Nothing Nothing "curl -X GET -H 'Content-Type: application/json' http://testnet.sushichain.io:3000/api/v1/blockchain" ex model.error
                ]
            ]
        ]
