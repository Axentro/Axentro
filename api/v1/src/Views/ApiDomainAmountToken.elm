module Views.ApiDomainAmountToken exposing (..)

import Html.Events exposing (onClick, onInput)
import Json.PrettyPrint
import Views.ApiAddressAmount exposing (confirmationQueryParams)
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


pageApiDomainAmountToken : Model -> List (Html Msg)
pageApiDomainAmountToken model =
    let
        description =
            div [] [ Html.text "This retrieves amounts of tokens for the specified token for a domain as Json" ]

        ex = """{"status":"success","result":{"confirmation":1,"pairs":[{"token":"EAGLE","amount":100000}]}}"""
    in
        [ br [] []
        , Grid.row []
            [ apiLeftNav ApiDomainAmountToken
            , Grid.col [ Col.md9 ]
                [ documentation ApiDomainAmountToken model.apiUrlD3 Nothing model.apiResponse "Domain Amount Token" description "GET" "api/v1/domain/{:domain}/token/{:token}" (Just confirmationQueryParams) Nothing "curl -X GET -H 'Content-Type: application/json' http://testnet.sushichain.io:3000/api/v1/domain/{:domain}/token/{:token}" ex model.error
                ]
            ]
        ]
