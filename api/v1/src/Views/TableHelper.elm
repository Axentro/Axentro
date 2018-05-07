module Views.TableHelper exposing (..)

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
import Messages exposing (Msg(..))


docTable : Table.THead msg -> Table.TBody msg -> Html.Html msg
docTable tableHeader tableBody =
    Table.table
        { options = [ Table.bordered ]
        , thead = tableHeader
        , tbody = tableBody
        }
