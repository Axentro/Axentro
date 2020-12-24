# Copyright © 2017-2020 The Axentro Core developers
#
# See the LICENSE file at the top-level directory of this distribution
# for licensing information.
#
# Unless otherwise agreed in a custom licensing agreement with the Axentro Core developers,
# no part of this software, including this file, may be copied, modified,
# propagated, or distributed except according to the terms contained in the
# LICENSE file.
#
# Removal or modification of this copyright notice is prohibited.

require "i18n"

I18n.load_path += ["#{__DIR__}/../../locales/**/"]
I18n.init
locale = ENV["AXENTRO_LOCALE"]? ? ENV["AXENTRO_LOCALE"] : "en"
I18n.default_locale = locale
I18n::Backend::Yaml.embed(["src/locales/axe", "src/locales/global_optionparser", "src/locales/help"])
