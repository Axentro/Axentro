module Views.ApiDomainUnconfirmedToken exposing (..)

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


pageApiDomainUnconfirmedToken : Model -> List (Html Msg)
pageApiDomainUnconfirmedToken model =
    let
        description =
            div [] [ Html.text "This retrieves amounts of unconfirmed tokens for the specified token for a domain as Json" ]

        ex = """{"status":"success","result":{"confirmed":false,"pairs":[{"token":"EAGLE","amount":100000}]}}"""
    in
        [ br [] []
        , Grid.row []
            [ apiLeftNav ApiDomainUnconfirmedToken
            , Grid.col [ Col.md9 ]
                [ documentation ApiDomainUnconfirmedToken model.apiUrlD5 model.apiResponse "Domain Unconfirmed Token" description "GET" "v1/domain/{:domain}/unconfirmed/{:token}" "curl -X GET -H 'Content-Type: application/json' http://testnet.sushichain.io:3000/v1/domain/{:domain}/unconfirmed/{:token}" ex
                ]
            ]
        ]
