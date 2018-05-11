module Views.ApiTokenList exposing (..)

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


pageApiTokenList : Model -> List (Html Msg)
pageApiTokenList model =
    let
        description =
            div [] [ Html.text "Shows a list of all available tokens as Json" ]

        ex = """{"result":["SHARI"],"status":"success"}"""
    in
        [ br [] []
        , Grid.row []
            [ apiLeftNav ApiTokenList
            , Grid.col [ Col.md9 ]
                [ documentation ApiTokenList model.apiUrlTK1 Nothing model.apiResponse "Tokens" description "GET" "api/v1/tokens" Nothing Nothing "curl -X GET -H 'Content-Type: application/json' http://testnet.sushichain.io:3000/api/v1/tokens" ex model.error
                ]
            ]
        ]
