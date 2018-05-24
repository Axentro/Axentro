module Views.ApiNodes exposing (..)

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


pageApiNodes : Model -> List (Html Msg)
pageApiNodes model =
    let
        description =
            div [] [ Html.text "Show information about the connecting nodes" ]

        ex = """{"status":"success","result":{"successor_list":[],"predecessor":"","private_nodes":[]}}"""
    in
        [ br [] []
        , Grid.row []
            [ apiLeftNav ApiNodes
            , Grid.col [ Col.md9 ]
                [ documentation ApiNodes model.apiUrlN3 Nothing model.apiResponse "Nodes" description "GET" "api/v1/nodes" Nothing Nothing "curl -X GET -H 'Content-Type: application/json' http://testnet.sushichain.io:3000/api/v1/nodes" ex model.error
                ]
            ]
        ]
