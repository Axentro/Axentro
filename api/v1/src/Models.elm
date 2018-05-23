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
    , apiUrlT6 : String
    , apiUrlT7 : String
    , apiUrlA1 : String
    , apiUrlA2 : String
    , apiUrlA3 : String
    , apiUrlD1 : String
    , apiUrlD2 : String
    , apiUrlD3 : String
    , apiUrlS1 : String
    , apiUrlS2 : String
    , apiBody  : String
    , apiUrlTK1 : String
    }