
module Hellbender
  module UtilMethods

    # handle UTF-8 and latin-1 encodings
    def guess_encoding(str)
      str.force_encoding("UTF-8")
      unless str.valid_encoding?
        str.encode!("UTF-8", "ISO-8859-1")
      end
    end

    # convert nicks to lowercase with IRC rules
    def irccase(nick)
      nick.downcase.tr("[]\\", "{}|")
    end

  end

  class Util
    extend UtilMethods
  end
end
