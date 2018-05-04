module Models exposing (..)

import Messages exposing (ViewState(..))


type alias NewWalletModel =
    { name : String
    , password : String
    , passwordConfirm : String
    }


emptyNewWallet : NewWalletModel
emptyNewWallet =
    { name = ""
     , password = ""
     , passwordConfirm = ""
     }


type alias Model =
    { currentViewState : ViewState
    , newWalletModel : NewWalletModel
    }


newModel : Model
newModel =
    { currentViewState = EntryView
    , newWalletModel = emptyNewWallet
    }
