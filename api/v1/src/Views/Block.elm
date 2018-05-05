module Views.Block exposing (..)

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
import Messages exposing (Msg(..))
import Views.ApiOverview exposing (apiOverviewTable)

overviewBlockSection =
    [ hr [] []
    , h3 [] [ text "Block" ]
    , apiOverviewTable
        (Table.tbody []
            [ Table.tr []
                [ Table.td [] [ Html.text "GET" ]
                , Table.td [] [ a [ href "" ] [ Html.text "v1/block{:index}" ] ]
                , Table.td [] [ Html.text "full block at index" ]
                ]
            , Table.tr []
                [ Table.td [] [ Html.text "GET" ]
                , Table.td [] [ a [ href "" ] [ Html.text "v1/block/{:index}/header" ] ]
                , Table.td [] [ Html.text "block header at index" ]
                ]
            , Table.tr []
                [ Table.td [] [ Html.text "GET" ]
                , Table.td [] [ a [ href "" ] [ Html.text "v1/block/{:index}/transactions" ] ]
                , Table.td [] [ Html.text "transactions in block" ]
                ]
            ]
        )
    ]