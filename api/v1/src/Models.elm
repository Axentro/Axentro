module Models exposing (..)

import Messages exposing (Page)
import Bootstrap.Navbar as Navbar

type alias Model =
    { page : Page
    , navState : Navbar.State
    , apiResponse : String
    , error : String
    , apiUrlB1 : String
    , apiUrlB2 : String
    , apiUrlB3 : String
    , apiUrlB4 : String
    , apiUrlB5 : String
    , apiUrlB6 : String
    , apiUrlT1 : String
    , apiUrlT2 : String
    , apiUrlT3 : String
    , apiUrlT4 : String
    , apiUrlT5 : String
    }