module Models exposing (..)

import Messages exposing (Page)
import Bootstrap.Navbar as Navbar

type alias Model =
    { page : Page
    , navState : Navbar.State
    }