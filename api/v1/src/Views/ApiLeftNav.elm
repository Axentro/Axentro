module Views.ApiLeftNav exposing (..)

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
import Messages exposing (Msg(..), Page(..))


apiLeftNav : Page -> Grid.Column Msg
apiLeftNav page =
    Grid.col [ Col.md3 ]
        [ hr [] []
        , h5 [] [ text "BlockChain" ]
        , link ApiBlockchain "#api-blockchain" "blockchain" page
        , link ApiBlockchainHeader "#api-blockchain-header" "blockchain/header" page
        , link ApiBlockchainSize "#api-blockchain-size" "blockchain/size" page
        , hr [] []
        , h5 [] [ text "Block" ]
        , div [] [ a [ href "#api-block" ] [ text "block" ] ]
        , div [] [ a [ href "#api-block-header" ] [ text "block/header" ] ]
        , div [] [ a [ href "#api-block-transactions" ] [ text "block/transactions" ] ]
        ]


link : Page -> String -> String -> Page -> Html Msg
link thisPage url desc currentPage =
    if thisPage == currentPage then
        div [] [ div [ class "badge badge-secondary" ] [ a [ style [ ( "color", "white" ) ], href url ] [ text desc ] ] ]
    else
        div [] [ div [] [ a [ href url ] [ text desc ] ] ]
